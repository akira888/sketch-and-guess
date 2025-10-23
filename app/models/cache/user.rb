class Cache::User < CacheModel
  # Attributes
  attribute :name, :string
  attribute :room_id, :string
  attribute :sketch_book_id, :integer # 自分のスケッチブックID（永続化されたSketchBook）
  attribute :current_sketch_book_id, :integer # 現在持っているスケッチブックID（オプション）

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

  # Find by room_id
  def self.find_by_room(room_id)
    # Note: This requires iteration or a separate index
    # For now, this is a placeholder
    raise NotImplementedError, "Use Cache::Room.member_order_array to get users in a room"
  end

  # Check if user is holding their own sketch book
  def holding_own_book?
    sketch_book_id.present? && sketch_book_id == current_sketch_book_id
  end

  # Get the sketch book the user is currently holding
  def current_sketch_book
    return nil unless current_sketch_book_id.present?
    SketchBook.find_by(id: current_sketch_book_id)
  end

  # Get the user's own sketch book
  def own_sketch_book
    return nil unless sketch_book_id.present?
    SketchBook.find_by(id: sketch_book_id)
  end
end
