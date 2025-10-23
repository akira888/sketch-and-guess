# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2025_10_23_200826) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "pages", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.integer "page_number", null: false
    t.string "page_type", null: false
    t.integer "sketch_book_id", null: false
    t.datetime "updated_at", null: false
    t.string "user_name", null: false
    t.index ["page_type"], name: "index_pages_on_page_type"
    t.index ["sketch_book_id", "page_number"], name: "index_pages_on_sketch_book_id_and_page_number", unique: true
    t.index ["sketch_book_id"], name: "index_pages_on_sketch_book_id"
  end

  create_table "prompts", force: :cascade do |t|
    t.integer "card_num"
    t.datetime "created_at", null: false
    t.integer "order"
    t.datetime "updated_at", null: false
    t.string "word"
  end

  create_table "sketch_books", force: :cascade do |t|
    t.boolean "completed", default: false, null: false
    t.datetime "created_at", null: false
    t.string "owner_name", null: false
    t.integer "prompt_id", null: false
    t.text "prompt_text"
    t.string "room_id", null: false
    t.integer "round", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["completed"], name: "index_sketch_books_on_completed"
    t.index ["prompt_id"], name: "index_sketch_books_on_prompt_id"
    t.index ["room_id", "round"], name: "index_sketch_books_on_room_id_and_round"
    t.index ["room_id"], name: "index_sketch_books_on_room_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "pages", "sketch_books"
  add_foreign_key "sketch_books", "prompts"
end
