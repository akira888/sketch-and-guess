class GameManager
  attr_reader :room

  def initialize(room)
    @room = room
  end

  private

  # 1ページ目（お題ページ）を作成
  def create_prompt_page(sketch_book, user_name, prompt_text)
    Page.create!(
      sketch_book_id: sketch_book.id,
      page_number: 1,
      page_type: "prompt",
      content: prompt_text,
      user_name: user_name
    )
  end

  # Cache::Gameの初期化
  def initialize_game(sketch_books)
    # 偶数人か奇数人かで初期ターンが異なる
    member_names = room.member_names
    player_count = member_names.size
    is_even = player_count.even?

    # sketch_book_holdersの初期設定
    holders = {}
    sketch_books.each do |sb_info|
      book = sb_info[:sketch_book]
      user_name = sb_info[:user_name]

      # 偶数人: 最初は自分が持つ
      # 奇数人: 最初から隣に渡す
      if is_even
        holders[book.id.to_s] = user_name
      else
        # 隣の人に渡す
        current_index = member_names.index(user_name)
        next_index = (current_index + 1) % member_names.length
        holders[book.id.to_s] = member_names[next_index]
      end
    end

    # Cache::Gameを作成
    game = Cache::Game.new(
      id: room.id, # room_idをIDとして使用
      room_id: room.id,
      current_turn: 2, # ターン1は初期化フェーズ、ターン2から開始
      turn_type: "sketch", # 最初は絵を描く
      turn_started_at: Time.current,
      current_round: 1,
      status: "in_progress",
      sketch_book_holders: holders.to_json
    )
    game.save!

    game
  end

  # 既存のCache::Gameをゲーム開始用に更新
  def update_game_for_start(game, sketch_books)
    # 偶数人か奇数人かで初期ターンが異なる
    member_names = room.member_names
    player_count = member_names.size
    is_even = player_count.even?

    # sketch_book_holdersの初期設定
    holders = {}
    sketch_books.each do |sb_info|
      book = sb_info[:sketch_book]
      user_name = sb_info[:user_name]

      # 偶数人: 最初は自分が持つ
      # 奇数人: 最初から隣に渡す
      if is_even
        holders[book.id.to_s] = user_name
      else
        # 隣の人に渡す
        current_index = member_names.index(user_name)
        next_index = (current_index + 1) % member_names.length
        holders[book.id.to_s] = member_names[next_index]
      end
    end

    # ゲームの状態を更新
    game.current_turn = 2 # ターン2から開始（ターン1はお題選択フェーズ）
    game.turn_type = "sketch"
    game.status = "in_progress"
    game.sketch_book_holders = holders.to_json
    game.save!
  end

  # Cache::Userにスケッチブックを割り当て
  def update_user_sketch_books(game, sketch_books)
    sketch_books.each do |sb_info|
      book = sb_info[:sketch_book]
      user_id = sb_info[:user_id]
      user_name = sb_info[:user_name]

      # Cache::Userを取得して更新
      user = Cache::User.find(user_id)
      if user
        user.sketch_book_id = book.id

        # 現在持っているスケッチブックを設定
        current_holder_name = game.current_holder(book.id)
        if current_holder_name == user_name
          user.current_sketch_book_id = book.id
        end

        user.save!
      end
    end

    # 奇数人の場合、current_sketch_book_idも更新が必要
    unless sketch_books.size.even?
      # 各ユーザーの current_sketch_book_id を更新
      sketch_books.each do |sb_info|
        book = sb_info[:sketch_book]
        current_holder_name = game.current_holder(book.id)

        # current_holder_nameのユーザーを探す
        holder_info = sketch_books.find { |info| info[:user_name] == current_holder_name }
        if holder_info
          holder = Cache::User.find(holder_info[:user_id])
          holder.current_sketch_book_id = book.id
          holder.save!
        end
      end
    end
  end
end
