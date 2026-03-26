class UsersController < ApplicationController
  before_action :find_room, only: [ :new, :create ]

  def new
    room_id = @cache_room.id

    # 別のルームから来た場合は、古いユーザー情報をクリア
    if session[:room_id] && session[:room_id] != room_id
      session[:user_id] = nil
    end

    session[:room_id] = room_id
    @cache_user = Cache::User.new(room_id:)
  end

  def create
    render "busy", status: 403 if @cache_room.full?

    @cache_user = Cache::User.new(user_params)
    # 参加者リストに追加
    @cache_room.add_member(@cache_user)
    # カード持たせる
    game = Cache::Game.find_by_room(@cache_room.id)
    @cache_user.assigned_card_num = game.pick_prompt_card
    if @cache_user.save && game.save && @cache_room.save
      session[:user_id] = @cache_user.id

      # スケッチブックも作る
      sketch_book = SketchBook.new(owner_name: @cache_user.name, room_id: @cache_room.id)
      if sketch_book.save
        redirect_to new_sketch_book_first_page_path(sketch_book)
      else
        flash.now[:alert] = "ユーザー作成中にエラーが発生しました。リトライしてください"
        render :new, status: :unprocessable_entity
      end
    else
      render :new
    end
  end

  def show
    @cache_user = Cache::User.find(params[:id])
    unless @cache_user
      render "not_found", status: 404
    end
  end

  private

  def user_params
    params.require("cache_user").permit(:name, :room_id)
  end

  def find_room
    @cache_room = Cache::Room.find(session[:room_id] || params[:room_id])
    render "not_found", status: 404 unless @cache_room
  end

  def broadcast_room_update(room)
    # 参加者数を更新
    Turbo::StreamsChannel.broadcast_update_to(
      "room_#{room.id}",
      target: "participant-count",
      html: "参加人数: <strong>#{room.entering_count} / #{room.member_limit}</strong>"
    )

    # 参加者一覧を更新
    Turbo::StreamsChannel.broadcast_update_to(
      "room_#{room.id}",
      target: "participants",
      partial: "rooms/participants",
      locals: { cache_room: room }
    )

    # ルームステータスを更新（待機メッセージ）
    Turbo::StreamsChannel.broadcast_update_to(
      "room_#{room.id}",
      target: "room-status",
      partial: "rooms/room_status",
      locals: { cache_room: room }
    )
  end

  def broadcast_game_start(room)
    # ルームステータスを更新して、全員に「ゲーム開始」を通知
    # room_statusパーシャルで自動リダイレクトを処理
    Turbo::StreamsChannel.broadcast_update_to(
      "room_#{room.id}",
      target: "room-status",
      partial: "rooms/room_status",
      locals: { cache_room: room, game_started: true }
    )
  end

  def broadcast_prompt_selection_start(room)
    # 全員をお題選択画面にリダイレクト
    Turbo::StreamsChannel.broadcast_append_to(
      "room_#{room.id}",
      target: "body",
      html: <<~HTML
        <script>
          console.log('お題選択フェーズが始まりました');
          window.location.href = '/rooms/#{room.id}/prompt_selection';
        </script>
      HTML
    )
  end
end
