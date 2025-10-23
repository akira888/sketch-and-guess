class SketchBooksController < ApplicationController
  before_action :set_current_user
  before_action :set_sketch_book, only: [ :show, :add_page ]
  before_action :set_game, only: [ :show, :add_page ]

  def show
    # 現在のターンタイプに応じて表示を変える
    @current_turn = @game.current_turn
    @turn_type = @game.turn_type
    @room = Cache::Room.find(@game.room_id)

    # 最新のページを取得（前のプレイヤーが書いたもの）
    @latest_page = @sketch_book.pages.ordered.last

    # 次のページ番号を計算
    @next_page_number = @sketch_book.pages.count + 1
  end

  def add_page
    # ページタイプに応じてパラメータを処理
    if @game.sketch_turn?
      add_sketch_page
    elsif @game.text_turn?
      add_text_page
    else
      flash[:alert] = "無効なターンタイプです"
      redirect_to sketch_book_path(@sketch_book)
    end
  end

  private

  def set_current_user
    user_id = session[:user_id]
    @current_user = Cache::User.find(user_id)

    unless @current_user
      flash[:alert] = "ユーザー情報が見つかりません"
      redirect_to root_path
    end
  end

  def set_sketch_book
    @sketch_book = SketchBook.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    flash[:alert] = "スケッチブックが見つかりません"
    redirect_to root_path
  end

  def set_game
    @game = Cache::Game.find_by_room(@sketch_book.room_id)

    unless @game
      flash[:alert] = "ゲーム情報が見つかりません"
      redirect_to root_path
    end
  end

  def add_sketch_page
    # 画像をアップロード
    image = params[:image]

    unless image
      flash[:alert] = "画像をアップロードしてください"
      redirect_to sketch_book_path(@sketch_book) and return
    end

    page_number = @sketch_book.pages.count + 1
    page = Page.new(
      sketch_book_id: @sketch_book.id,
      page_number: page_number,
      page_type: :sketch,
      user_name: @current_user.name
    )
    page.image.attach(image)

    if page.save
      check_and_advance_turn
    else
      flash[:alert] = "ページの保存に失敗しました: #{page.errors.full_messages.join(', ')}"
      redirect_to sketch_book_path(@sketch_book)
    end
  end

  def add_text_page
    content = params[:content]

    unless content.present?
      flash[:alert] = "テキストを入力してください"
      redirect_to sketch_book_path(@sketch_book) and return
    end

    page_number = @sketch_book.pages.count + 1
    page = Page.create(
      sketch_book_id: @sketch_book.id,
      page_number: page_number,
      page_type: :text,
      content: content,
      user_name: @current_user.name
    )

    if page.persisted?
      check_and_advance_turn
    else
      flash[:alert] = "ページの保存に失敗しました: #{page.errors.full_messages.join(', ')}"
      redirect_to sketch_book_path(@sketch_book)
    end
  end

  def check_and_advance_turn
    room = Cache::Room.find(@game.room_id)
    sketch_books = SketchBook.by_room(@game.room_id).by_round(@game.current_round)

    # 全員がページを追加したかチェック
    all_completed = sketch_books.all? do |book|
      book.pages.count >= @game.current_turn
    end

    if all_completed
      # スケッチブックを回す
      @game.rotate_sketch_books!(room.member_names)

      # 全員に戻ったかチェック
      if @game.all_books_returned?(sketch_books)
        # ラウンド終了
        sketch_books.each(&:mark_as_completed!)
        @game.finish_round!

        # 次のラウンドがあるかチェック
        if @game.current_round < room.total_round
          # 次のラウンド開始準備
          flash[:notice] = "ラウンド#{@game.current_round}が終了しました！"
          redirect_to room_path(room.id)
        else
          # ゲーム終了
          @game.finish!
          flash[:notice] = "ゲームが終了しました！"
          redirect_to results_room_path(room.id)
        end
      else
        # 次のターンへ
        @game.next_turn!

        # current_sketch_book_idを更新
        update_current_sketch_books(room, sketch_books)

        flash[:notice] = "ページを追加しました"
        # 次に持つスケッチブックにリダイレクト
        redirect_to sketch_book_path(@current_user.reload.current_sketch_book_id)
      end
    else
      # 待機画面へ
      flash[:notice] = "ページを追加しました。他のプレイヤーを待っています..."
      redirect_to sketch_book_path(@sketch_book)
    end
  end

  def update_current_sketch_books(room, sketch_books)
    # 各ユーザーのcurrent_sketch_book_idを更新
    room.member_order_array.each do |member|
      user = Cache::User.find(member["user_id"])
      next unless user

      # このユーザーが現在持っているスケッチブックを探す
      current_book = sketch_books.find do |book|
        @game.current_holder(book.id) == user.name
      end

      if current_book
        user.current_sketch_book_id = current_book.id
        user.save!
      end
    end
  end
end
