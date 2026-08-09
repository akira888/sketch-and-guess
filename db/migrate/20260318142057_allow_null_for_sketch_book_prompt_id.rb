class AllowNullForSketchBookPromptId < ActiveRecord::Migration[8.1]
  def change
    change_column_null :sketch_books, :prompt_id, true
  end
end
