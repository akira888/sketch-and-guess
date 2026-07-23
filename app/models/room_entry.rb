# frozen_string_literal: true

class RoomEntry
  attr_reader :room, :user, :sketch_book

  def initialize(room)
    @room = room
  end

  # SketchBookの作成、Userの生成、ルームへの入室処理をまとめて行い、ゲーム参加への準備をする
  def join_user(user_params)
    @user = Cache::User.new(user_params)
    game = Cache::Game.find_by_room(room.id)
    @sketch_book = SketchBook.new(owner_name: user.name, room_id: room.id)
    return false unless sketch_book.save

    user.assigned_card_num = game.pick_prompt_card
    user.assigned_count = 1
    user.sketch_book_id = @sketch_book.id
    return false unless user.save && game.save

    room.add_member(user)
  end
end
