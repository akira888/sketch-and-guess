require "test_helper"

# GET /rooms/:id/next_page — 行き先解決アクション
# 「いま自分が持っているブック」を sketch_book_id_held_by で解決し、
# そのブックの pages/new へ redirect する。スタート時も毎ターンの合流点としても使う
class RoomsNextPageTest < ActionDispatch::IntegrationTest
  MODERN_UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
              "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36".freeze

  setup do
    @room = Cache::Room.new(member_limit: 2, total_round: 1)
    @room.save
    Cache::Game.new(room_id: @room.id).save

    # 実フローで2人入室（session・スケッチブック作成をまとめて成立させる）
    get user_entry_path(@room.id), headers: { "HTTP_USER_AGENT" => MODERN_UA }
    post users_path,
         params: { cache_user: { name: "たろう", room_id: @room.id } },
         headers: { "HTTP_USER_AGENT" => MODERN_UA }
    @user = Cache::User.find(session[:user_id])

    @second = open_session
    @second.get user_entry_path(@room.id), headers: { "HTTP_USER_AGENT" => MODERN_UA }
    @second.post users_path,
                 params: { cache_user: { name: "はなこ", room_id: @room.id } },
                 headers: { "HTTP_USER_AGENT" => MODERN_UA }
    @second_user = Cache::User.find(@second.session[:user_id])
  end

  test "next_page: スタート直後（偶数2人）は自分のブックの pages/new へ redirect する" do
    start_game!

    get next_page_room_path(@room.id), headers: { "HTTP_USER_AGENT" => MODERN_UA }

    assert_redirected_to new_sketch_book_page_path(@user.sketch_book_id)
  end

  test "next_page: ターンが進むと相手のブックの pages/new へ redirect する" do
    start_game!
    advance_turn!

    get next_page_room_path(@room.id), headers: { "HTTP_USER_AGENT" => MODERN_UA }

    assert_redirected_to new_sketch_book_page_path(@second_user.sketch_book_id)
  end

  test "next_page: 別セッションのユーザーはそれぞれ自分の行き先へ redirect される" do
    start_game!

    @second.get next_page_room_path(@room.id), headers: { "HTTP_USER_AGENT" => MODERN_UA }

    @second.assert_redirected_to new_sketch_book_page_path(@second_user.sketch_book_id)
  end

  test "pages/new: 受け皿ページが表示できる" do
    start_game!

    get new_sketch_book_page_path(@user.sketch_book_id),
        headers: { "HTTP_USER_AGENT" => MODERN_UA }

    assert_response :success
  end

  private

  # 配置 → waiting → prompt_selection → in_progress（ターン1・sketch）まで進める
  def start_game!
    room = Cache::Room.find(@room.id)
    game = Cache::Game.find_by_room(@room.id)
    game.distribute_sketch_books!(room.members)
    game.facilitator.proceed! # waiting -> prompt_selection
    Cache::Game.find_by_room(@room.id).facilitator.proceed! # -> in_progress, ターン1
  end

  def advance_turn!
    game = Cache::Game.find_by_room(@room.id)
    game.current_turn += 1
    game.save!
  end
end
