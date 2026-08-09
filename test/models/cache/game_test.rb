require "test_helper"

class Cache::GameTest < ActiveSupport::TestCase
  # RoomsController は Cache::Game.new(room_id:).save の戻り値を見ていないため、
  # デフォルト値がバリデーションに反するとサイレントに保存失敗する（過去に発生）。
  # その回帰防止テスト
  test "room_id だけ指定した新規 Game はデフォルト値のまま保存できる" do
    game = Cache::Game.new(room_id: "room-1")

    assert game.save, "保存に失敗: #{game.errors.full_messages.join(', ')}"
    assert Cache::Game.find_by_room("room-1").waiting?
  end

  test "roll_dice は prompt_selection 中なら 1〜6 の目を保存して true を返す" do
    game = create_game(status: "prompt_selection")

    assert game.roll_dice

    reloaded = Cache::Game.find_by_room(game.room_id)
    assert_includes 1..6, reloaded.dice_result
  end

  test "roll_dice は prompt_selection 以外では振らずに false を返す" do
    game = create_game(status: "waiting")

    assert_not game.roll_dice
    assert_nil Cache::Game.find_by_room(game.room_id).dice_result
  end

  test "roll_dice は既に出目があるときは振り直さず false を返す" do
    game = create_game(status: "prompt_selection", dice_result: 4)

    assert_not game.roll_dice
    assert_equal 4, Cache::Game.find_by_room(game.room_id).dice_result
  end

  # ---- pick_prompt_card: FREE 除外 ----
  # FREE（自由入力）は未実装のため、FREE お題を含むカードは配布対象から外す。
  # fixture: card 1,2,3 = 通常 / card 4 = FREE のみ / card 5 = FREE:ジャンル + 通常お題

  test "pick_prompt_card は通常カードを重複なく配る" do
    game = create_game(status: "waiting")

    picked = 3.times.map { game.pick_prompt_card }

    assert_equal [ 1, 2, 3 ], picked.sort
  end

  test "pick_prompt_card は FREE お題を含むカードを配らない" do
    game = create_game(status: "waiting")

    # 引き切っても FREE 入りカードは現れない（バグがあれば5枚全部が picked に入る）
    5.times { game.pick_prompt_card }
    game.save!

    reloaded = Cache::Game.find_by_room(game.room_id)
    assert_not_includes reloaded.picked_cards, 4, "word=FREE のカードが配られた"
    assert_not_includes reloaded.picked_cards, 5, "FREE:ジャンル を含むカードが配られた"
  end

  # ---- distribute_sketch_books!: スタート時の初期配置 ----
  # holders への書き込みはこの1回だけ（以降のローテーションは計算で導出）。
  # 偶数人: 各ブックはオーナー自身が持つ / 奇数人: 最初から隣（member 順で次の人）に渡す

  test "distribute_sketch_books! 偶数人では各ブックをオーナー自身が持つ" do
    game = create_game(status: "prompt_selection")
    members = [
      create_member(name: "たろう", sketch_book_id: 10),
      create_member(name: "はなこ", sketch_book_id: 20)
    ]

    game.distribute_sketch_books!(members)

    holders = Cache::Game.find_by_room(game.room_id).holders_hash
    assert_equal members[0].id, holders["10"]
    assert_equal members[1].id, holders["20"]
  end

  test "distribute_sketch_books! 奇数人では各ブックを隣（member 順で次の人）が持つ" do
    game = create_game(status: "prompt_selection")
    members = [
      create_member(name: "たろう", sketch_book_id: 10),
      create_member(name: "はなこ", sketch_book_id: 20),
      create_member(name: "じろう", sketch_book_id: 30)
    ]

    game.distribute_sketch_books!(members)

    holders = Cache::Game.find_by_room(game.room_id).holders_hash
    assert_equal members[1].id, holders["10"], "たろうのブックは隣のはなこへ"
    assert_equal members[2].id, holders["20"], "はなこのブックは隣のじろうへ"
    assert_equal members[0].id, holders["30"], "末尾じろうのブックは先頭のたろうへ巻き戻る"
  end

  # ---- sketch_book_id_held_by: 現在の持ち主の計算導出 ----
  # holders（初期セット）は差し替えず、current_turn の進みから巡回位置を計算する。
  # 経過ターン数 = current_turn - 1（スタート時 = ターン1 = 初期配置のまま。ターン0 = お題ページ）

  test "sketch_book_id_held_by 偶数人: スタート時は自分のブック、次ターンは隣のブックを持つ" do
    members, game = start_game(member_count: 2)
    taro, hanako = members

    # ターン1（スタート直後）: 初期配置のまま
    assert_equal taro.sketch_book_id, game.sketch_book_id_held_by(taro.id)
    assert_equal hanako.sketch_book_id, game.sketch_book_id_held_by(hanako.id)

    game = advance_turn(game) # ターン2

    assert_equal hanako.sketch_book_id, game.sketch_book_id_held_by(taro.id)
    assert_equal taro.sketch_book_id, game.sketch_book_id_held_by(hanako.id)
  end

  test "sketch_book_id_held_by 奇数人: スタート時から隣のブックを持ち、順に巡回する" do
    members, game = start_game(member_count: 3)
    a, b, c = members

    # ターン1: 初期配置（自分のブックは隣へ渡し済み → 自分は前の人のブックを持つ）
    assert_equal c.sketch_book_id, game.sketch_book_id_held_by(a.id)
    assert_equal a.sketch_book_id, game.sketch_book_id_held_by(b.id)
    assert_equal b.sketch_book_id, game.sketch_book_id_held_by(c.id)

    game = advance_turn(game) # ターン2: さらに1つ巡回

    assert_equal b.sketch_book_id, game.sketch_book_id_held_by(a.id)
    assert_equal c.sketch_book_id, game.sketch_book_id_held_by(b.id)
    assert_equal a.sketch_book_id, game.sketch_book_id_held_by(c.id)
  end

  test "sketch_book_id_held_by 人数分ターンが進むと初期配置に戻る" do
    members, game = start_game(member_count: 3)
    initial = members.map { |m| game.sketch_book_id_held_by(m.id) }

    3.times { game = advance_turn(game) } # 1周

    assert_equal initial, members.map { |m| game.sketch_book_id_held_by(m.id) }
  end

  private

  def create_game(**attrs)
    game = Cache::Game.new(room_id: "room-1", **attrs)
    game.save!
    game
  end

  def create_member(name:, sketch_book_id:)
    user = Cache::User.new(name:, room_id: "room-1", sketch_book_id:)
    user.save!
    user
  end

  # 入室〜スタート直後（ターン1・初期配置済み）までを再現する
  def start_game(member_count:)
    room = Cache::Room.new(member_limit: member_count, total_round: 1)
    room.save!
    members = member_count.times.map do |i|
      user = Cache::User.new(name: "user#{i}", room_id: room.id, sketch_book_id: (i + 1) * 10)
      user.save!
      room.add_member(user)
      user
    end
    game = Cache::Game.new(room_id: room.id, status: "in_progress",
                           current_turn: 1, turn_type: "sketch")
    game.save!
    game.distribute_sketch_books!(members)
    [ members, Cache::Game.find_by_room(room.id) ]
  end

  def advance_turn(game)
    game.current_turn += 1
    game.save!
    Cache::Game.find_by_room(game.room_id)
  end
end
