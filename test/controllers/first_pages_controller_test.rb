require "test_helper"

class FirstPagesControllerTest < ActionDispatch::IntegrationTest
  MODERN_UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
              "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36".freeze

  setup do
    @room = Cache::Room.new(member_limit: 2, total_round: 1)
    @room.save
    Cache::Game.new(room_id: @room.id).save

    # 実フローで入室（session・カード割当・スケッチブック作成をまとめて成立させる）
    get user_entry_path(@room.id), headers: { "HTTP_USER_AGENT" => MODERN_UA }
    post users_path,
         params: { cache_user: { name: "たろう", room_id: @room.id } },
         headers: { "HTTP_USER_AGENT" => MODERN_UA }
    @user = Cache::User.find(session[:user_id])
    @sketch_book = SketchBook.find(@user.sketch_book_id)
  end

  test "create: 出目確定後はカード×出目の prompt を内容とする1ページ目が作られる" do
    roll_dice_as(1)

    post_create

    first_page = @sketch_book.pages.find_by(page_number: 1)
    expected_word = Prompt.find_by_card_and_order(@user.assigned_card_num, 1).word
    assert_redirected_to sketch_book_first_page_path(@sketch_book)
    assert_equal expected_word, first_page.content
    assert_equal "たろう", first_page.user_name
  end

  # タイマー自動送信の二重 POST 対策（冪等性）
  test "create: 既に1ページ目があれば作らず show へリダイレクトする" do
    roll_dice_as(1)
    post_create
    first_page = @sketch_book.pages.find_by(page_number: 1)

    assert_no_difference -> { Page.count } do
      post_create
    end

    assert_redirected_to sketch_book_first_page_path(@sketch_book)
  end

  test "create: 出目が未確定なら 422 でページは作られない" do
    # game は waiting のまま（dice_result なし）

    post_create

    assert_response :unprocessable_entity
    assert_nil @sketch_book.pages.find_by(page_number: 1)
  end

  # ---- #new: 揃った判定と状態遷移の冪等性（GET 連打で状態が進まないこと） ----

  test "new: 全員揃う前は game を進めない" do
    # member_limit 2 に対して1人だけ入室済み
    get_new

    assert_response :success
    game = Cache::Game.find_by_room(@room.id)
    assert game.waiting?
    assert_nil game.dice_result
  end

  test "new: 全員揃ってもカード未決定の間は game を進めない" do
    join_second_user name: "はなこ"
    decide_card @user # はなこは未決定

    get_new

    assert Cache::Game.find_by_room(@room.id).waiting?
  end

  test "new: 全員揃ってカード決定済みなら prompt_selection に進み出目が確定する" do
    join_second_user name: "はなこ"
    all_members_decide_card

    get_new

    assert_response :success
    game = Cache::Game.find_by_room(@room.id)
    assert game.prompt_selection?
    assert_includes 1..6, game.dice_result
  end

  test "new: 揃った後のリロードでは状態も出目も変わらない（冪等）" do
    join_second_user name: "はなこ"
    all_members_decide_card
    get_new
    game = Cache::Game.find_by_room(@room.id)
    first_dice = game.dice_result

    3.times { get_new } # リロード連打

    reloaded = Cache::Game.find_by_room(@room.id)
    assert reloaded.prompt_selection?, "リロードで状態が進んではいけない"
    assert_equal first_dice, reloaded.dice_result, "リロードで出目が変わってはいけない"
  end

  test "new: 後続ユーザーのアクセスでも状態と出目は変わらない" do
    second = join_second_user name: "はなこ"
    all_members_decide_card
    get_new # 1人目のアクセスで確定
    first_dice = Cache::Game.find_by_room(@room.id).dice_result

    second_user = Cache::User.find(second.session[:user_id])
    second.get new_sketch_book_first_page_path(SketchBook.find(second_user.sketch_book_id)),
               headers: { "HTTP_USER_AGENT" => MODERN_UA }

    game = Cache::Game.find_by_room(@room.id)
    assert game.prompt_selection?
    assert_equal first_dice, game.dice_result
  end

  # ---- #show: 全員の1ページ目が揃ったらゲームスタート ----
  # 最後に show へ到達した人がスタートを踏む（distribute → proceed! → broadcast）。
  # 誰が何度アクセスしても結果が変わらないこと（冪等）を保証する

  test "show: 全員の1ページ目が揃っていなければゲームは始まらない" do
    join_second_user name: "はなこ"
    all_members_decide_card
    roll_dice_as(1) # prompt_selection へ遷移＋出目固定（fixture は order 1 のみ網羅のため）
    post_create # 1人目だけ1ページ目を作成（2人目は未作成）

    get_show

    game = Cache::Game.find_by_room(@room.id)
    assert game.prompt_selection?, "全員揃う前にスタートしてはいけない"
  end

  test "show: 全員の1ページ目が揃った後の show でゲームがスタートする" do
    second = join_second_user name: "はなこ"
    all_members_decide_card
    roll_dice_as(1)
    post_create
    create_first_page_as(second)

    get_show

    game = Cache::Game.find_by_room(@room.id)
    second_user = Cache::User.find(second.session[:user_id])
    assert game.in_progress?
    assert_equal 1, game.current_turn
    assert game.sketch_turn?
    # 偶数2人: 初期配置は自分のブック
    assert_equal @user.sketch_book_id, game.sketch_book_id_held_by(@user.id)
    assert_equal second_user.sketch_book_id, game.sketch_book_id_held_by(second_user.id)
  end

  test "show: スタート後のリロード連打で状態が変わらない（冪等）" do
    second = join_second_user name: "はなこ"
    all_members_decide_card
    roll_dice_as(1)
    post_create
    create_first_page_as(second)
    get_show # スタート
    started = Cache::Game.find_by_room(@room.id)

    3.times { get_show }

    reloaded = Cache::Game.find_by_room(@room.id)
    assert reloaded.in_progress?
    assert_equal started.current_turn, reloaded.current_turn, "リロードでターンが進んではいけない"
    assert_equal started.holders_hash, reloaded.holders_hash, "リロードで配置が変わってはいけない"
  end

  private

  # 全員 ready 後に FirstPages#new で行われる状態遷移＋ダイス確定を再現する
  def roll_dice_as(result)
    game = Cache::Game.find_by_room(@room.id)
    game.facilitator.proceed! # waiting -> prompt_selection
    game = Cache::Game.find_by_room(@room.id)
    game.dice_result = result
    game.save!
  end

  def get_new
    get new_sketch_book_first_page_path(@sketch_book),
        headers: { "HTTP_USER_AGENT" => MODERN_UA }
  end

  # 別ブラウザ（別セッション）で2人目を入室させる
  def join_second_user(name:)
    session = open_session
    session.get user_entry_path(@room.id), headers: { "HTTP_USER_AGENT" => MODERN_UA }
    session.post users_path,
                 params: { cache_user: { name:, room_id: @room.id } },
                 headers: { "HTTP_USER_AGENT" => MODERN_UA }
    session
  end

  def decide_card(user)
    user = Cache::User.find(user.id)
    user.card_decided = true
    user.save!
  end

  def all_members_decide_card
    Cache::Room.find(@room.id).members.each { |member| decide_card(member) }
  end

  def post_create
    post sketch_book_first_page_path(@sketch_book),
         headers: { "HTTP_USER_AGENT" => MODERN_UA }
  end

  def get_show
    get sketch_book_first_page_path(@sketch_book),
        headers: { "HTTP_USER_AGENT" => MODERN_UA }
  end

  # 別セッションのユーザーとして1ページ目を作成する
  def create_first_page_as(session)
    user = Cache::User.find(session.session[:user_id])
    book = SketchBook.find(user.sketch_book_id)
    session.post sketch_book_first_page_path(book),
                 headers: { "HTTP_USER_AGENT" => MODERN_UA }
  end
end
