class AddWinProbabilityToParticipants < ActiveRecord::Migration[8.1]
  def change
    add_column :participants, :win_probability, :decimal, precision: 5, scale: 1, default: 0.0
  end
end
