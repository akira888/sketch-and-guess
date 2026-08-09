class GameFacilitator
  def initialize(game)
    @game = game
  end

  def proceed!
    @game.status = case @game.status
    when "waiting"
        "prompt_selection"
    when "prompt_selection"
        proceed_turn
        "in_progress"
    when "in_progress"
        "round_finished"
    when "round_finished"
        "finished"
    else
        raise NameError, "ゲームステータスが不明です"
    end

    @game.save!
  end

  def proceed_turn
    @game.current_turn += 1
    @game.turn_type = case @game.turn_type
    when "prompt", "text"
        "sketch"
    else
        "text"
    end
  end
end
