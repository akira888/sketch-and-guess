class GameManager
  attr_reader :room

  def initialize(room)
    @room = room
  end

  # ゲーム開始処理
  def start_game!
    raise "ルームが満員ではありません" unless room.full?

    ActiveRecord::Base.transaction do
      # 1. お題の配布
      dice_roll = roll_dice
      prompts_by_user = distribute_prompts(dice_roll)

      # 2. スケッチブックの作成
      sketch_books = create_sketch_books(prompts_by_user)

      # 3. Cache::Gameの初期化
      game = initialize_game(sketch_books)

      # 4. Cache::Userのcurrent_sketch_book_idを設定
      update_user_sketch_books(game, sketch_books)

      game
    end
  end

  private

  # ダイスを振る（1-6のランダム値）
  def roll_dice
    rand(1..6)
  end

  # お題の配布
  # @return [Hash] { { user_id:, user_name: } => Prompt }
  def distribute_prompts(dice_roll)
    member_order = room.member_order_array
    player_count = member_order.size

    # プレイヤー数分の異なるcard_numを選択
    available_card_nums = Prompt.distinct.pluck(:card_num)
    selected_card_nums = available_card_nums.sample(player_count)

    # 各プレイヤーにお題を割り当て
    prompts_by_user = {}
    member_order.each_with_index do |member, index|
      card_num = selected_card_nums[index]
      prompt = Prompt.find_by_card_and_order(card_num, dice_roll)

      unless prompt
        raise "お題が見つかりません (card_num: #{card_num}, order: #{dice_roll})"
      end

      prompts_by_user[member] = prompt
    end

    prompts_by_user
  end

  # スケッチブックの作成
  def create_sketch_books(prompts_by_user)
    sketch_books = []
    current_round = 1 # 初回は1ラウンド目

    prompts_by_user.each do |member, prompt|
      user_id = member["user_id"]
      user_name = member["user_name"]

      sketch_book = SketchBook.create!(
        room_id: room.id,
        owner_name: user_name,
        prompt_id: prompt.id,
        round: current_round,
        completed: false
      )

      # 1ページ目（promptページ）を作成
      create_prompt_page(sketch_book, user_name, prompt)

      # スケッチブックとユーザーの関連付けを保存
      sketch_books << { sketch_book: sketch_book, user_id: user_id, user_name: user_name }
    end

    sketch_books
  end

  # 1ページ目（お題ページ）を作成
  def create_prompt_page(sketch_book, user_name, prompt)
    Page.create!(
      sketch_book_id: sketch_book.id,
      page_number: 1,
      page_type: "prompt",
      content: prompt.word,
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
