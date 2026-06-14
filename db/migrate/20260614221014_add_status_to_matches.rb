class AddStatusToMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :status, :string
  end
end
