class Cache::Room < CacheModel

  # 人数制限
  attribute :member_limit, :integer
  # ゲームラウンド数
  attribute :total_round, :integer
  # 登録人数
  attribute :entering_count, :integer

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

  def full?
    member_limit == entering_count
  end
end
