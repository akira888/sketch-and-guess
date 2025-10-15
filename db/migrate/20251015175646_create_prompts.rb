class CreatePrompts < ActiveRecord::Migration[8.0]
  def change
    create_table :prompts do |t|
      t.string :word
      t.integer :order
      t.integer :card_num

      t.timestamps
    end
  end
end
