require "test_helper"

class RoomEntryTest < ActiveSupport::TestCase
  setup do
    @room = Cache::Room.new(member_limit: 2, total_round: 1)
    @room.save
    # rooms#create と同様、ルーム作成時に Game も存在する前提
    Cache::Game.new(room_id: @room.id).save
  end

  test "成功時: user が保存され、カードとスケッチブックが紐づく" do
    entry = RoomEntry.new(@room)

    assert entry.join_user({ name: "たろう", room_id: @room.id })

    user = Cache::User.find(entry.user.id)
    assert_equal "たろう", user.name
    assert_equal 1, user.assigned_count
    assert_not_nil user.assigned_card_num
    assert_equal entry.sketch_book.id, user.sketch_book_id
  end

  test "成功時: スケッチブックが本人の名義・部屋で永続化される" do
    entry = RoomEntry.new(@room)
    entry.join_user({ name: "たろう", room_id: @room.id })

    sketch_book = SketchBook.find(entry.sketch_book.id)
    assert_equal "たろう", sketch_book.owner_name
    assert_equal @room.id, sketch_book.room_id
  end

  test "成功時: room の参加者リストに追加される" do
    entry = RoomEntry.new(@room)
    entry.join_user({ name: "たろう", room_id: @room.id })

    assert_equal [ entry.user.id ], Cache::Room.find(@room.id).member_ids
  end

  test "成功時: 引いたカードは game の picked_cards に記録される" do
    entry = RoomEntry.new(@room)
    entry.join_user({ name: "たろう", room_id: @room.id })

    game = Cache::Game.find_by_room(@room.id)
    assert_includes game.picked_cards, entry.user.assigned_card_num
  end

  test "2人目は1人目と別のカードを引く" do
    RoomEntry.new(@room).join_user({ name: "たろう", room_id: @room.id })

    reloaded_room = Cache::Room.find(@room.id)
    entry2 = RoomEntry.new(reloaded_room)
    entry2.join_user({ name: "はなこ", room_id: reloaded_room.id })

    card_nums = Cache::Room.find(@room.id).members.map(&:assigned_card_num)
    assert_equal card_nums.uniq, card_nums
  end

  test "失敗時（名前なし）: false を返し、参加者リストに追加されない" do
    entry = RoomEntry.new(@room)

    assert_not entry.join_user({ name: "", room_id: @room.id })

    # コミットポイント（add_member）まで到達しないため room は無傷
    assert_equal [], Cache::Room.find(@room.id).member_ids
  end
end
