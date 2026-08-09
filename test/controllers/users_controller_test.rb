require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  # allow_browser versions: :modern 対策（モダンブラウザの UA を名乗る）
  MODERN_UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
              "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36".freeze

  setup do
    @old_room = create_room
    @new_room = create_room
  end

  # 招待 URL（user_entry）が真実の源であること:
  # 古いセッションの残骸（session[:room_id]）が URL のルームを
  # 上書きしてしまい、Game を持たない残骸ルームへ誘導される事故の回帰防止
  test "entry: session に別ルームが残っていても URL のルームのフォームが表示される" do
    visit_entry @old_room

    visit_entry @new_room

    assert_response :success
    assert_includes response.body, @new_room.id
  end

  test "entry: 到達時点で古い session[:user_id] は常にクリアされる" do
    visit_entry @old_room
    join_room @old_room, name: "たろう"
    assert session[:user_id].present?

    visit_entry @new_room

    assert_nil session[:user_id]
  end

  test "create: 成功時にフォームのルームが session に登録される" do
    visit_entry @new_room

    join_room @new_room, name: "たろう"

    assert_equal @new_room.id, session[:room_id]
    assert_equal session[:user_id], Cache::Room.find(@new_room.id).member_ids.first
  end

  # マルチタブシナリオ: タブ1でルームB、タブ2でルームCの entry を開いた後、
  # タブ1のフォームを送信 → session ではなくフォームのルームBに参加すること
  test "create: 後から別ルームの entry を開いていてもフォームのルームに参加する" do
    visit_entry @old_room # タブ1（フォームは @old_room のもの）
    visit_entry @new_room # タブ2（session が汚染される）

    join_room @old_room, name: "たろう" # タブ1のフォームを送信

    assert_response :redirect
    assert_equal [ "たろう" ], Cache::Room.find(@old_room.id).members.map(&:name)
    assert_equal [], Cache::Room.find(@new_room.id).member_ids
    assert_equal @old_room.id, session[:room_id]
  end

  # 実際に起きた事故の再現シナリオ:
  # Game を持たない残骸ルームを踏んだ後でも、新しいルームの招待 URL から参加できること
  test "create: Game なしの残骸ルームを経由しても招待 URL のルームに参加できる" do
    broken_room = Cache::Room.new(member_limit: 2, total_round: 1)
    broken_room.save # Game は作らない（TTL 切れ等の残骸を再現）
    visit_entry broken_room

    visit_entry @new_room
    join_room @new_room, name: "次郎"

    assert_response :redirect
    assert_equal [ "次郎" ], Cache::Room.find(@new_room.id).members.map(&:name)
  end

  # session 切れ・TTL 切れは 404 → TOP へ誘導する方針
  test "entry: 存在しない（TTL 切れ）ルームの URL は 404" do
    get user_entry_path("expired-room-id"), headers: { "HTTP_USER_AGENT" => MODERN_UA }

    assert_response :not_found
  end

  test "create: 送信時点でルームが消えていたら 404" do
    visit_entry @new_room
    Rails.cache.clear # TTL 切れを再現

    join_room @new_room, name: "たろう"

    assert_response :not_found
  end

  private

  def create_room
    room = Cache::Room.new(member_limit: 2, total_round: 1)
    room.save
    Cache::Game.new(room_id: room.id).save
    room
  end

  def visit_entry(room)
    get user_entry_path(room.id), headers: { "HTTP_USER_AGENT" => MODERN_UA }
  end

  def join_room(room, name:)
    post users_path,
         params: { cache_user: { name:, room_id: room.id } },
         headers: { "HTTP_USER_AGENT" => MODERN_UA }
  end
end
