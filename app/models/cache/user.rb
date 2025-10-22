class Cache::User < CacheModel
  # Attributes
  attribute :name, :string
  attribute :room_id, :string
  attribute :sketch_book_id, :string


  # Validations
  validates :name, presence: true
  validates :room_id, presence: true

  # Configuration
  def self.cache_key_prefix
    "cache_user"
  end

  def self.default_ttl
    1.day
  end
end
