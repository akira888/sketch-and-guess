# frozen_string_literal: true

# Cache::Game stored in SolidCache
#
# Example usage:
#   game = Cache::Game.new(
#     room_id: nil,
#     current_turn: nil,
#     turn_type: nil,
#     turn_started_at: nil,
#     current_round: nil,
#     status: nil,
#     sketch_book_holders: nil,
#   )
#   game.save
#
#   # Later...
#   game = Cache::Game.find("some_id")
#   game.destroy
class Cache::Game < CacheModel
  # Attributes
  attribute :room_id, :string
  attribute :current_turn, :integer, default: 1
  attribute :turn_type, :string, default: "sketch"
  attribute :turn_started_at, :datetime
  attribute :current_round, :integer, default: 1
  attribute :status, :string, default: "waiting"
  attribute :sketch_book_holders, :string # JSON string for current holders
  attribute :dice_result, :integer # ダイスの出目（1-6）

  # Validations
  validates :room_id, presence: true
  validates :current_turn, numericality: { greater_than: 0 }
  validates :current_round, numericality: { greater_than: 0 }
  validates :status, inclusion: { in: %w[waiting prompt_selection in_progress round_finished finished] }
  validates :turn_type, inclusion: { in: %w[sketch text] }
  validates :dice_result, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 6 }, allow_nil: true

  # Configuration
  def self.cache_key_prefix
    "cache_game"
  end

  def self.default_ttl
    2.hours
  end

  # Find by room_id (use room_id as the cache key)
  def self.find_by_room(room_id)
    find(room_id)
  end

  # Parse sketch_book_holders JSON
  def holders_hash
    return {} if sketch_book_holders.blank?
    JSON.parse(sketch_book_holders)
  rescue JSON::ParserError
    {}
  end

  # Set sketch_book_holders from hash
  def holders_hash=(hash)
    self.sketch_book_holders = hash.to_json
  end

  # Status checks
  def waiting?
    status == "waiting"
  end

  def prompt_selection?
    status == "prompt_selection"
  end

  def in_progress?
    status == "in_progress"
  end

  def round_finished?
    status == "round_finished"
  end

  def finished?
    status == "finished"
  end

  # Turn type checks
  def sketch_turn?
    turn_type == "sketch"
  end

  def text_turn?
    turn_type == "text"
  end

  # Game progression methods
  def start!
    self.status = "in_progress"
    self.turn_started_at = Time.current
    save!
  end

  def next_turn!
    self.current_turn += 1
    # Turn type based on turn number
    # Even turns (2, 4, 6, ...): sketch
    # Odd turns (3, 5, 7, ...): text
    self.turn_type = current_turn.even? ? "sketch" : "text"
    self.turn_started_at = Time.current
    save!
  end

  def next_round!
    self.current_round += 1
    self.current_turn = 1
    self.turn_type = "sketch"
    self.status = "in_progress"
    self.turn_started_at = Time.current
    save!
  end

  def finish_round!
    self.status = "round_finished"
    save!
  end

  def finish!
    self.status = "finished"
    save!
  end

  # Get current holder of a sketch book
  def current_holder(sketch_book_id)
    holders_hash[sketch_book_id.to_s]
  end

  # Set current holder of a sketch book
  def set_holder(sketch_book_id, user_name)
    hash = holders_hash
    hash[sketch_book_id.to_s] = user_name
    self.holders_hash = hash
    save!
  end

  # Rotate sketch books to next holders
  def rotate_sketch_books!(member_order)
    hash = holders_hash
    new_hash = {}

    hash.each do |sketch_book_id, current_holder|
      current_index = member_order.index(current_holder)
      next_index = (current_index + 1) % member_order.length
      new_hash[sketch_book_id] = member_order[next_index]
    end

    self.holders_hash = new_hash
    save!
  end

  # Check if all sketch books have returned to original owners
  def all_books_returned?(sketch_books)
    sketch_books.all? do |book|
      current_holder(book.id) == book.owner_name
    end
  end

  private

  # Custom ID generation: use room_id as ID
  def generate_id
    self.id = room_id
  end
end
