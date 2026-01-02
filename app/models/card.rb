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
#
# カードというデータ構造はなく、 Prompt#card_num によってお題が６つごとにグルーピングされているところから
# card has_many prompts のような状態になるため擬似的なデータ構造をモデルで表現している
# ユーザーはcard単位でお題候補を一時的に保持し、乱数ルーレットにより手持ちのカードから一つのお題が選定される
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
    1.hour
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
