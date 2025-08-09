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

ActiveRecord::Schema[8.0].define(version: 2025_08_09_210514) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "plans", force: :cascade do |t|
    t.bigint "provider_id", null: false
    t.string "name"
    t.jsonb "details"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider_id"], name: "index_plans_on_provider_id"
  end

  create_table "providers", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "rate_limits", force: :cascade do |t|
    t.bigint "provider_id", null: false
    t.integer "limit"
    t.integer "remaining"
    t.datetime "reset_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider_id"], name: "index_rate_limits_on_provider_id"
  end

  create_table "usage_records", force: :cascade do |t|
    t.bigint "provider_id", null: false
    t.integer "user_id"
    t.integer "request_count"
    t.datetime "timestamp"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider_id"], name: "index_usage_records_on_provider_id"
  end

  add_foreign_key "plans", "providers"
  add_foreign_key "rate_limits", "providers"
  add_foreign_key "usage_records", "providers"
end
