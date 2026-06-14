class CreatePredictions < ActiveRecord::Migration[8.1]
  def change
    create_table :predictions do |t|
      t.references :participant, null: false, foreign_key: true
      t.references :match, null: false, foreign_key: true
      t.integer :home_score, null: false
      t.integer :away_score, null: false
      t.integer :points, default: 0

      t.index [:participant_id, :match_id], unique: true
      t.timestamps
    end
  end
end
