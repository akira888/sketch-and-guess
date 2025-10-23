class Prompt < ApplicationRecord
  # Associations
  has_many :sketch_books, dependent: :nullify

  # Validations
  validates :word, presence: true
  validates :order, presence: true, inclusion: { in: 1..6 }
  validates :card_num, presence: true

  # Scopes
  scope :by_card, ->(card_num) { where(card_num: card_num) }
  scope :by_order, ->(order) { where(order: order) }

  # Class methods
  def self.find_by_card_and_order(card_num, order)
    find_by(card_num: card_num, order: order)
  end

  # Instance methods
  def free_input?
    word == "FREE"
  end
end
