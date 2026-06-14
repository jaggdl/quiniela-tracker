class CreateMatches < ActiveRecord::Migration[8.1]
  def change
    create_table :matches do |t|
      t.string :home_team, null: false
      t.string :away_team, null: false
      t.integer :match_number, null: false
      t.integer :matchday, null: false
      t.integer :home_score
      t.integer :away_score

      t.index [:matchday, :match_number], unique: true

      t.timestamps
    end
  end
end
