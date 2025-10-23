class Cache::Room < CacheModel
  # 人数制限
  attribute :member_limit, :integer
  # ゲームラウンド数
  attribute :total_round, :integer
  # 登録人数
  attribute :entering_count, :integer
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

  # Add member to the order
  def add_member(user_name)
    array = member_order_array
    array << user_name unless array.include?(user_name)
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
end
