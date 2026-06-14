class CreateParticipants < ActiveRecord::Migration[8.1]
  def change
    create_table :participants do |t|
      t.string :name, null: false
      t.integer :position
      t.integer :total_points, default: 0

      t.timestamps
    end
  end
end
