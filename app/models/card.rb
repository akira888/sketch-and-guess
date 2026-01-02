# Card stored in SolidCache
#
# Example usage:
#   card = Card.new(
#     user_id: nil,
#     card_num: nil,
#   )
#   card.save
#
#   # Later...
#   card = Card.find("some_id")
#   card.destroy
class Card < CacheModel
  # Attributes
  attribute :user_id, :integer
  attribute :card_num, :integer

  # Validations
  validates :user_id, presence: true
  validates :card_num, presence: true

  # Configuration
  def self.cache_key_prefix
    "card"
  end

  def self.default_ttl
    1.day
  end

  # Custom methods
  # def custom_method
  #   # Your logic here
  # end

  private

  def generate_id
    self.id = SecureRandom.uuid
  end
end
