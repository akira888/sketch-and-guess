class Page < ApplicationRecord
  # Associations
  belongs_to :sketch_book
  has_one_attached :image

  # Enums
  enum :page_type, {
    prompt: "prompt",
    sketch: "sketch",
    text: "text"
  }, validate: true

  # Validations
  validates :page_number, presence: true, numericality: { greater_than: 0 }
  validates :page_type, presence: true
  validates :user_name, presence: true
  validates :sketch_book_id, uniqueness: { scope: :page_number }

  # Custom validations
  validate :content_or_image_present

  # Scopes
  scope :ordered, -> { order(:page_number) }
  scope :by_type, ->(type) { where(page_type: type) }

  # Instance methods
  def sketch?
    page_type == "sketch"
  end

  def text?
    page_type == "text"
  end

  def prompt?
    page_type == "prompt"
  end

  private

  def content_or_image_present
    if sketch?
      errors.add(:image, "must be attached for sketch pages") unless image.attached?
    elsif text? || prompt?
      errors.add(:content, "must be present for text/prompt pages") if content.blank?
    end
  end
end
