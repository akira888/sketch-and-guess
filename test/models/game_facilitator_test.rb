require "test_helper"

class GameFacilitatorTest < ActiveSupport::TestCase
  test "proceed! は waiting → prompt_selection に進めて保存する" do
    game = create_game(status: "waiting")

    game.facilitator.proceed!

    assert Cache::Game.find_by_room(game.room_id).prompt_selection?
  end

  test "proceed! は prompt_selection → in_progress に進める" do
    game = create_game(status: "prompt_selection")

    game.facilitator.proceed!

    assert Cache::Game.find_by_room(game.room_id).in_progress?
  end

  # ゲームスタート時はターン状態も整合させる。
  # ターン番号の規約: 0 = お題ページ、1 = 最初の絵（ゼロ起点）
  test "proceed! は prompt_selection → in_progress でターン状態をスタート位置にする" do
    game = create_game(status: "prompt_selection")

    game.facilitator.proceed!

    reloaded = Cache::Game.find_by_room(game.room_id)
    assert_equal 1, reloaded.current_turn, "スタート時は最初の絵ターン（1）"
    assert reloaded.sketch_turn?, "最初のターンは絵を描く"
  end

  test "proceed! は prompt_selection 以外の遷移ではターン状態を変えない" do
    game = create_game(status: "in_progress")
    game.current_turn = 3
    game.turn_type = "text"
    game.save!

    game.facilitator.proceed! # -> round_finished

    reloaded = Cache::Game.find_by_room(game.room_id)
    assert_equal 3, reloaded.current_turn
    assert reloaded.text_turn?
  end

  test "proceed! は in_progress → round_finished に進める" do
    game = create_game(status: "in_progress")

    game.facilitator.proceed!

    assert Cache::Game.find_by_room(game.room_id).round_finished?
  end

  test "proceed! は round_finished → finished に進める" do
    game = create_game(status: "round_finished")

    game.facilitator.proceed!

    assert Cache::Game.find_by_room(game.room_id).finished?
  end

  test "proceed! は finished からはエラーになり状態を変えない" do
    game = create_game(status: "finished")

    assert_raises(NameError) { game.facilitator.proceed! }
    assert Cache::Game.find_by_room(game.room_id).finished?
  end

  private

  def create_game(status:)
    game = Cache::Game.new(room_id: "room-1", status:)
    game.save!
    game
  end
end
