require "test_helper"

class Cache::RoomTest < ActiveSupport::TestCase
  setup do
    @room = Cache::Room.new(member_limit: 2, total_round: 1)
    @room.save
  end

  test "add_member は保存済みユーザーの id を永続化する" do
    user = create_user("たろう")

    @room.add_member(user)

    reloaded = Cache::Room.find(@room.id)
    assert_equal [ user.id ], reloaded.member_ids
  end

  test "members は Cache::User の配列を返す" do
    user = create_user("たろう")
    @room.add_member(user)

    members = Cache::Room.find(@room.id).members

    assert_equal [ Cache::User ], members.map(&:class).uniq
    assert_equal [ "たろう" ], members.map(&:name)
  end

  test "full? は参加者が member_limit 人に達したとき true になる" do
    assert_not @room.full?

    @room.add_member(create_user("たろう"))
    assert_not Cache::Room.find(@room.id).full?

    # 2人目は別リクエストを想定してリロードした room に追加
    Cache::Room.find(@room.id).add_member(create_user("はなこ"))
    assert Cache::Room.find(@room.id).full?
  end

  test "entering_count は参加人数を返す" do
    assert_equal 0, @room.entering_count

    @room.add_member(create_user("たろう"))
    assert_equal 1, Cache::Room.find(@room.id).entering_count
  end

  private

  def create_user(name)
    user = Cache::User.new(name:, room_id: @room.id)
    user.save
    user
  end
end
