# お題決めるフェーズ
class FirstPagesController < ApplicationController
  before_action :set_sketch_book, only: [ :new, :create, :show ]
  before_action :set_current_user, only: [ :new, :create, :show ]

  def new
    @page = @sketch_book.pages.build(
      page_number: 1,
      page_type: :prompt,
      user_name: @current_user.name
    )
    @card = PromptCard.find @current_user.assigned_card_num
    @room = Cache::Room.find @current_user.room_id
    @game = Cache::Game.find_by_room(@room.id)

    # ユーザーが集まったとき
    if @room.full? && all_user_ready?(@room)
      if @game.waiting?
        @game.facilitator.proceed!
      end

      # サイコロを振る
      broadcast_dice_result(@game.dice_result) if @game.roll_dice

      if @game.dice_result.nil?
        flash.now[:alert] = "ゲームが進行できませんでした。リロードして下さい"
        render :new and return
      end
    end
  end

  def create
    # フォームからパラメータはわたってこない。
    # 必要な情報は各モデルから取り出す

    # first page が登録済みの場合はshowへ移動
    if @sketch_book.pages.find_by(page_number: 1)
      return redirect_to sketch_book_first_page_path(@sketch_book)
    end

    @game = Cache::Game.find_by_room(@current_user.room_id)
    prompt = Prompt.find_by_card_and_order(@current_user.assigned_card_num, @game&.dice_result)

    unless prompt
      flash.now[:alert] = "お題カードか指定番号が決まっていないようです"
      # new template parameters
      @room = Cache::Room.find @current_user.room_id
      @card = PromptCard.find @current_user.assigned_card_num
      return render :new, status: :unprocessable_entity
    end

    first_page = @sketch_book.pages.build(
      page_number: 1, page_type: :prompt,
      user_name: @current_user.name,
      content: prompt.word
    )
    if first_page.save || @sketch_book.pages.find_by(page_number: 1)
      redirect_to sketch_book_first_page_path(@sketch_book), notice: "お題を確認しましょう"
    else
      flash.now[:alert] = "お題ページの作成に失敗しました"
      # new template parameters
      @room = Cache::Room.find @current_user.room_id
      @card = PromptCard.find @current_user.assigned_card_num
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @page = @sketch_book.pages.find_by!(page_number: 1)
    @room = Cache::Room.find(@current_user.room_id)
    @game = Cache::Game.find_by_room(@room.id)
    if @game.prompt_selection? && all_user_has_first_page?(@room.members)
      @game.distribute_sketch_books!(@room.members)
      @game.facilitator.proceed!
      broadcast_next_page
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
    Turbo::StreamsChannel.broadcast_update_to(
      @room.dice_channel,
      target: helpers.dom_id(@game, :dice_result),
      method: "morph",
      partial: "first_pages/dice_result",
      locals: { dice_result: dice_result, game: @game }
    )
  end

  def broadcast_next_page
    Turbo::StreamsChannel.broadcast_update_to(
      @room.start_channel,
      target: helpers.dom_id(@game, :next_page),
      method: "morph",
      partial: "first_pages/next_page",
      locals: { room: @room, game: @game }
    )
  end

  def all_user_has_first_page?(members)
    first_page_count = Page.where(sketch_book_id: members.map(&:sketch_book_id)).by_type(:prompt).count
    members.size == first_page_count
  end
end
