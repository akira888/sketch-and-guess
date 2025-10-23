class SketchBook < ApplicationRecord
  # Associations
  belongs_to :prompt
  has_many :pages, dependent: :destroy

  # Validations
  validates :room_id, presence: true
  validates :owner_name, presence: true
  validates :round, presence: true, numericality: { greater_than: 0 }

  # Scopes
  scope :by_room, ->(room_id) { where(room_id: room_id) }
  scope :by_round, ->(round) { where(round: round) }
  scope :completed, -> { where(completed: true) }
  scope :in_progress, -> { where(completed: false) }

  # Instance methods
  def mark_as_completed!
    update!(completed: true)
  end

  def expected_page_count(player_count)
    # 1ページ目（お題） + プレイヤー数分のターン
    player_count + 1
  end

  def completed?
    # completedフラグで判定
    # または、ページ数で判定することも可能
    completed
  end
end
