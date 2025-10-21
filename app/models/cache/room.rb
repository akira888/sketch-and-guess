# frozen_string_literal: true

# Cache::Room stored in SolidCache
#
# Example usage:
#   room = Cache::Room.new(
#     room_id: nil,
#     member_limit: nil,
#     total_round: nil,
#   )
#   room.save
#
#   # Later...
#   room = Cache::Room.find("some_id")
#   room.destroy
class Cache::Room < CacheModel
  # Attributes
  attribute :room_id, :string
  attribute :member_limit, :integer
  attribute :total_round, :integer

  # Validations
  # validates :some_field, presence: true
  # validate :custom_validation

  # Configuration
  def self.cache_key_prefix
    "cache_room"
  end

  def self.default_ttl
    1.day
  end

  # Custom methods
  # def custom_method
  #   # Your logic here
  # end

  private

  # Custom ID generation (optional)
  # def generate_id
  #   self.id = SecureRandom.uuid
  # end
end
