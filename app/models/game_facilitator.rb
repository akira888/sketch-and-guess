class GameFacilitator
  def initialize(game)
    @game = game
  end

  def proceed!
    @game.status = case @game.status
      when "waiting"
        "prompt_selection"
      when "prompt_selection"
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
end
