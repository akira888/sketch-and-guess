# お題をカードとしてまとめる役割。出番はユーザーのお題が決まるまでの間だけ
# 都度card_numを受け取って生成される
class PromptCard
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :card_num, :integer
  attribute :prompts

  validates :card_num, presence: true

  def self.find(card_num)
    new(
      card_num:,
      prompts: Prompt.for_card(card_num).ordered.to_a
    )
  end

  def prompt_for_order(order)
    prompts.find { |prompt| prompt.order == order }
  end
end
