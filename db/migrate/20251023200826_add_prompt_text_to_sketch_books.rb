class AddPromptTextToSketchBooks < ActiveRecord::Migration[8.1]
  def change
    add_column :sketch_books, :prompt_text, :text
  end
end
