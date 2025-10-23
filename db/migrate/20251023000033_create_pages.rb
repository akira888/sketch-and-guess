class CreatePages < ActiveRecord::Migration[8.1]
  def change
    create_table :pages do |t|
      t.references :sketch_book, null: false, foreign_key: true
      t.integer :page_number, null: false
      t.string :page_type, null: false
      t.text :content
      t.string :user_name, null: false

      t.timestamps
    end

    add_index :pages, [:sketch_book_id, :page_number], unique: true
    add_index :pages, :page_type
  end
end
