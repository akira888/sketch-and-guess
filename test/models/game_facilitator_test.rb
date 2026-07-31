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
