class CreateSketchBooks < ActiveRecord::Migration[8.1]
  def change
    create_table :sketch_books do |t|
      t.string :room_id, null: false
      t.string :owner_name, null: false
      t.references :prompt, null: false, foreign_key: true
      t.integer :round, null: false, default: 1
      t.boolean :completed, null: false, default: false

      t.timestamps
    end

    add_index :sketch_books, :room_id
    add_index :sketch_books, [:room_id, :round]
    add_index :sketch_books, :completed
  end
end
