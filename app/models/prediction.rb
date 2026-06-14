class Prediction < ApplicationRecord
  belongs_to :participant
  belongs_to :match

  validates :home_score, :away_score, presence: true
  validates :points, numericality: { greater_than_or_equal_to: 0 }
  validates :match_id, uniqueness: { scope: :participant_id }

  def self.calc_points(actual_home, actual_away, pred_home, pred_away)
    return 0 if actual_home.nil? || actual_away.nil?

    if actual_home == pred_home && actual_away == pred_away
      3
    elsif (actual_home <=> actual_away) == (pred_home <=> pred_away)
      1
    else
      0
    end
  end

  def calculate_points
    return 0 unless match.home_score && match.away_score

    self.class.calc_points(match.home_score, match.away_score, home_score, away_score)
  end

  def refresh_points!
    update!(points: calculate_points)
  end
end
