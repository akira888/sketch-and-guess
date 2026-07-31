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

  private

  def create_game(**attrs)
    game = Cache::Game.new(room_id: "room-1", **attrs)
    game.save!
    game
  end
end
