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

ActiveRecord::Schema[8.1].define(version: 2026_11_02_100001) do
  create_table "app_events", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "event_name", null: false
    t.integer "restaurant_id"
    t.datetime "occurred_at", null: false
    t.datetime "exported_at"
    t.index ["exported_at"], name: "index_app_events_on_exported_at"
    t.index ["restaurant_id"], name: "index_app_events_on_restaurant_id"
    t.index ["user_id"], name: "index_app_events_on_user_id"
  end

  create_table "braze_deliveries", force: :cascade do |t|
    t.string "idempotency_key", null: false
    t.integer "user_id", null: false
    t.string "endpoint", null: false
    t.json "payload", null: false
    t.string "status", default: "pending", null: false
    t.integer "attempts", default: 0, null: false
    t.text "last_error"
    t.datetime "recorded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["idempotency_key"], name: "index_braze_deliveries_on_idempotency_key", unique: true
    t.index ["user_id"], name: "index_braze_deliveries_on_user_id"
  end

  create_table "cdi_watermarks", force: :cascade do |t|
    t.string "view_name", null: false
    t.datetime "synced_through"
    t.index ["view_name"], name: "index_cdi_watermarks_on_view_name", unique: true
  end

  create_table "restaurants", force: :cascade do |t|
    t.string "key", null: false
    t.string "name", null: false
    t.string "location_id", null: false
    t.string "cuisine"
    t.string "price"
    t.decimal "rating", precision: 2, scale: 1
    t.integer "cashback_pct"
    t.string "image_url"
    t.string "thumb_url"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_restaurants_on_key", unique: true
  end

  create_table "rewards", force: :cascade do |t|
    t.string "reward_key", null: false
    t.integer "user_id", null: false
    t.string "reward_type", null: false
    t.integer "amount_cents", null: false
    t.integer "min_spend_cents"
    t.datetime "redeemed_at"
    t.datetime "exported_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reward_key"], name: "index_rewards_on_reward_key", unique: true
    t.index ["user_id"], name: "index_rewards_on_user_id"
    t.index ["user_id"], name: "index_rewards_one_referral_welcome_per_user", unique: true, where: "reward_type = 'referral_welcome'"
  end

  create_table "saved_restaurants", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "restaurant_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["restaurant_id"], name: "index_saved_restaurants_on_restaurant_id"
    t.index ["user_id", "restaurant_id"], name: "index_saved_restaurants_on_user_id_and_restaurant_id", unique: true
    t.index ["user_id"], name: "index_saved_restaurants_on_user_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.string "transaction_key", null: false
    t.integer "user_id", null: false
    t.integer "restaurant_id"
    t.integer "subtotal_cents", null: false
    t.integer "tip_cents", default: 0, null: false
    t.boolean "reward_applied", default: false, null: false
    t.datetime "exported_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "reward_amount_cents"
    t.index ["restaurant_id"], name: "index_transactions_on_restaurant_id"
    t.index ["transaction_key"], name: "index_transactions_on_transaction_key", unique: true
    t.index ["user_id"], name: "index_transactions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "external_id", null: false
    t.string "email", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_users_on_external_id", unique: true
  end

  add_foreign_key "app_events", "restaurants"
  add_foreign_key "app_events", "users"
  add_foreign_key "braze_deliveries", "users"
  add_foreign_key "rewards", "users"
  add_foreign_key "saved_restaurants", "restaurants"
  add_foreign_key "saved_restaurants", "users"
  add_foreign_key "transactions", "restaurants"
  add_foreign_key "transactions", "users"
end
