class UsersController < ApplicationController
  def new
    @cache_room = Cache::Room.find params[:room_id]
    render "not_found", status: 404 unless @cache_room

    # 別のルームから来た場合は、古いユーザー情報をクリア
    if session[:room_id] && session[:room_id] != @cache_room.id
      session[:user_id] = nil
    end

    session[:room_id] = @cache_room.id
    @cache_user = Cache::User.new(room_id: @cache_room.id)
  end

  def create
    @cache_room = Cache::Room.find session[:room_id]

    if @cache_room.full?
      render "busy", status: 403
      return
    end

    @cache_user = Cache::User.new(user_params)
    if @cache_user.save
      # 参加者リストに追加
      @cache_room.add_member(@cache_user.id, @cache_user.name)
      session[:user_id] = @cache_user.id

      # Turbo Streamで待機中の他のユーザーに通知
      broadcast_room_update(@cache_room)

      # 定員に達したか確認
      if @cache_room.full?
        # お題選択フェーズへ
        begin
          game_manager = GameManager.new(@cache_room)
          game = game_manager.prepare_prompt_selection!

          # ユーザー情報を再読み込み（assigned_card_numが設定されている）
          @cache_user = Cache::User.find(@cache_user.id)

          # 全員をお題選択画面にリダイレクト
          broadcast_prompt_selection_start(@cache_room)

          flash[:notice] = "全員揃いました！お題を選びます"
          redirect_to prompt_selection_room_path(@cache_room.id)
        rescue => e
          flash[:alert] = "お題選択の準備に失敗しました: #{e.message}"
          redirect_to room_path(@cache_room.id)
        end
      else
        # まだ定員に達していない場合は待機画面へ
        flash[:notice] = "ルームに参加しました（#{@cache_room.entering_count}/#{@cache_room.member_limit}人）"
        redirect_to room_path(@cache_room.id)
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
