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

  private

  def create_game(**attrs)
    game = Cache::Game.new(room_id: "room-1", **attrs)
    game.save!
    game
  end
end
