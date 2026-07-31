# お題決めるフェーズ
class FirstPagesController < ApplicationController
  # TODO :create, :edit, :update
  before_action :set_sketch_book, only: [ :new ]
  before_action :set_current_user, only: [ :new ]

  def new
    @page = @sketch_book.pages.build(
      page_number: 1,
      page_type: :prompt,
      user_name: @current_user.name
    )
    @card = PromptCard.find @current_user.assigned_card_num

    room = Cache::Room.find @current_user.room_id
    game = Cache::Game.find_by_room(room.id)
    if room.full? && all_user_ready?(room)
      if game.waiting?
        game.facilitator.proceed!
      end

      unless game.roll_dice
        flash.now[:alert] = "ゲームが進行できませんでした。リロードして下さい"
        render :new and return
      end

      broadcast_dice_result(game.dice_result)
      # 結果を全員に共有→画面からcreateしてもらう（自動送信を想定）
      # createしたらshow に遷移→最初の1ページが完成し、お題が見えている状態
    end
  end

  private

  def set_sketch_book
    @sketch_book ||= SketchBook.find(params[:sketch_book_id])
  end

  def all_user_ready?(room)
    room.members.present? && room.members.all?(&:card_decided?)
  end

  def broadcast_dice_result(dice_result)
    # ダイス結果をブロードキャスト
    Turbo::StreamsChannel.broadcast_append_to(
      "room_#{id}_dice",
      target: "body",
      html: <<~HTML
        <script>
          window.diceResult = #{dice_result};
          const event = new CustomEvent('diceRolled', { detail: { result: #{dice_result} } });
          document.dispatchEvent(event);
        </script>
      HTML
    )
  end
end
