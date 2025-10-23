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
    # Base64画像データを取得
    image_data = params[:image_data]

    unless image_data.present?
      flash[:alert] = "画像データがありません"
      redirect_to sketch_book_path(@sketch_book) and return
    end

    # Base64データをデコードしてファイルに変換
    begin
      # "data:image/png;base64," の部分を削除
      image_data = image_data.sub(/^data:image\/\w+;base64,/, '')
      decoded_image = Base64.decode64(image_data)

      page_number = @sketch_book.pages.count + 1
      page = Page.new(
        sketch_book_id: @sketch_book.id,
        page_number: page_number,
        page_type: "sketch",
        user_name: @current_user.name
      )

      # StringIOを使ってActive Storageに添付
      page.image.attach(
        io: StringIO.new(decoded_image),
        filename: "sketch_#{Time.current.to_i}.png",
        content_type: "image/png"
      )

      if page.save
        check_and_advance_turn
      else
        flash[:alert] = "ページの保存に失敗しました: #{page.errors.full_messages.join(', ')}"
        redirect_to sketch_book_path(@sketch_book)
      end
    rescue => e
      flash[:alert] = "画像の処理に失敗しました: #{e.message}"
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
      page_type: "text",
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
          broadcast_redirect_to_room(room.id)
          flash[:notice] = "ラウンド#{@game.current_round}が終了しました！"
          redirect_to room_path(room.id)
        else
          # ゲーム終了
          @game.finish!
          broadcast_redirect_to_results(room.id)
          flash[:notice] = "ゲームが終了しました！"
          redirect_to results_room_path(room.id)
        end
      else
        # 次のターンへ
        @game.next_turn!

        # current_sketch_book_idを更新
        update_current_sketch_books(room, sketch_books)

        # 全員を次のスケッチブックにリダイレクト
        broadcast_next_turn(room)

        flash[:notice] = "ページを追加しました"
        # 次に持つスケッチブックにリダイレクト
        redirect_to sketch_book_path(@current_user.reload.current_sketch_book_id)
      end
    else
      # 待機中のプレイヤーに進捗を通知
      broadcast_waiting_status(room, sketch_books)

      # Turbo Streamで待機状態を表示（リダイレクトせずにストリーム購読を維持）
      respond_to do |format|
        format.html { redirect_to sketch_book_path(@sketch_book), notice: "ページを追加しました。他のプレイヤーを待っています..." }
        format.turbo_stream do
          completed_count = sketch_books.count { |book| book.pages.count >= @game.current_turn }
          total_count = sketch_books.count

          render turbo_stream: [
            turbo_stream.update("current-task", html: "<h2>他のプレイヤーを待っています...</h2>"),
            turbo_stream.update("waiting-info",
              html: "<p>ページを追加しました。#{completed_count}/#{total_count}人が完了しました。</p>")
          ]
        end
      end
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

  def broadcast_waiting_status(room, sketch_books)
    # 完了したプレイヤー数を計算
    completed_count = sketch_books.count { |book| book.pages.count >= @game.current_turn }
    total_count = sketch_books.count

    # 待機情報を更新（ゲーム画面内の待機メッセージエリアを想定）
    Turbo::StreamsChannel.broadcast_update_to(
      "game_#{room.id}",
      target: "waiting-info",
      html: "<p>#{completed_count}/#{total_count}人が完了しました。他のプレイヤーを待っています...</p>"
    )
  end

  def broadcast_next_turn(room)
    # 全ユーザーに次のターン開始を通知
    # 各ユーザーは自分のcurrent_sketch_book_idにリダイレクト
    html = <<~HTML
      <script>
        (function() {
          // 自分の次のスケッチブックIDを取得してリダイレクト
          fetch('#{game_next_turn_room_path(room.id)}')
            .then(response => response.json())
            .then(data => {
              if (data.sketch_book_id) {
                Turbo.visit(data.sketch_book_url);
              }
            });
        })();
      </script>
    HTML

    Turbo::StreamsChannel.broadcast_append_to(
      "game_#{room.id}",
      target: "body",
      html: html
    )
  end

  def broadcast_redirect_to_room(room_id)
    html = <<~HTML
      <script>
        Turbo.visit('#{room_path(room_id)}');
      </script>
    HTML

    Turbo::StreamsChannel.broadcast_append_to(
      "game_#{room_id}",
      target: "body",
      html: html
    )
  end

  def broadcast_redirect_to_results(room_id)
    html = <<~HTML
      <script>
        Turbo.visit('#{results_room_path(room_id)}');
      </script>
    HTML

    Turbo::StreamsChannel.broadcast_append_to(
      "game_#{room_id}",
      target: "body",
      html: html
    )
  end
end
