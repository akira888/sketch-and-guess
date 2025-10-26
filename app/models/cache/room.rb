class Cache::Room < CacheModel
  # 人数制限
  attribute :member_limit, :integer
  # ゲームラウンド数(今は1固定)
  attribute :total_round, :integer, default: 1
  # 登録人数
  attribute :entering_count, :integer, default: 0
  # メンバーの順序（スケッチブックを渡す順番）
  attribute :member_order, :string # JSON string: ["Alice", "Bob", "Carol", "Dave"]

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

  # Parse member_order JSON
  # Returns array of hashes: [{ "user_id" => "xxx", "user_name" => "yyy" }, ...]
  def member_order_array
    return [] if member_order.blank?
    JSON.parse(member_order)
  rescue JSON::ParserError
    []
  end

  # Set member_order from array
  def member_order_array=(array)
    self.member_order = array.to_json
  end

  # Get array of user names only (for backward compatibility)
  def member_names
    member_order_array.map { |m| m["user_name"] }
  end

  # Get array of user IDs only
  def member_ids
    member_order_array.map { |m| m["user_id"] }
  end

  # Add member to the order
  def add_member(user_id, user_name)
    array = member_order_array
    # Check if user is already in the list
    unless array.any? { |m| m["user_id"] == user_id }
      array << { "user_id" => user_id, "user_name" => user_name }
    end
    self.member_order_array = array
    self.entering_count = array.length
    save!
  end

  # Check if room is full
  def full?
    member_limit == entering_count
  end

  # Check if room can start (has minimum players)
  def can_start?
    entering_count >= 4 && entering_count <= member_limit
  end

  def room_channel
    "room_#{id}"
  end
end
