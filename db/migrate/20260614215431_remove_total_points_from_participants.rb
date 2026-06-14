class RemoveTotalPointsFromParticipants < ActiveRecord::Migration[8.1]
  def change
    remove_column :participants, :total_points, :integer
  end
end
