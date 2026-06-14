class Participant < ApplicationRecord
  has_many :predictions, dependent: :destroy
  has_many :matches, through: :predictions

  validates :name, presence: true

  def total_points
    predictions.sum(:points)
  end
end
