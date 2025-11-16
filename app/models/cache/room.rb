# memberという概念でUsersを扱える
class Cache::Room < CacheModel
  # 制限人数
  attribute :member_limit, :integer
  # ゲームラウンド数(今は1固定)
  attribute :total_round, :integer, default: 1

  # 参加者IDを登録順に保持する配列JSON
  attribute :member_ids_json, :string, default: "[]"

  # Validations
  validates :member_limit, presence: true
  validates :total_round, presence: true

  # Configuration
  def self.cache_key_prefix
    "cache_room"
  end

  def self.default_ttl
    1.day
  end

  def members
    @members ||= member_ids.map { |user_id| User.find user_id }
  end

  def add_member(user)
    member_ids << user.id
    @member_ids_json = member_ids.to_json

    save
  end

  def member_ids
    @member_ids ||= JSON.parse(member_ids_json)
  end

  def full?
    member_limit == members.count
  end

  def entering_count
    member_ids.count
  end

  def room_channel
    "room_#{id}"
  end
end
