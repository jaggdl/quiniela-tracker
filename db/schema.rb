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

ActiveRecord::Schema[8.1].define(version: 2026_06_14_221014) do
  create_table "matches", force: :cascade do |t|
    t.integer "away_score"
    t.string "away_team", null: false
    t.datetime "created_at", null: false
    t.integer "home_score"
    t.string "home_team", null: false
    t.integer "match_number", null: false
    t.integer "matchday", null: false
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["matchday", "match_number"], name: "index_matches_on_matchday_and_match_number", unique: true
  end

  create_table "participants", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position"
    t.datetime "updated_at", null: false
  end

  create_table "predictions", force: :cascade do |t|
    t.integer "away_score", null: false
    t.datetime "created_at", null: false
    t.integer "home_score", null: false
    t.integer "match_id", null: false
    t.integer "participant_id", null: false
    t.integer "points", default: 0
    t.datetime "updated_at", null: false
    t.index ["match_id"], name: "index_predictions_on_match_id"
    t.index ["participant_id", "match_id"], name: "index_predictions_on_participant_id_and_match_id", unique: true
    t.index ["participant_id"], name: "index_predictions_on_participant_id"
  end

  add_foreign_key "predictions", "matches"
  add_foreign_key "predictions", "participants"
end
