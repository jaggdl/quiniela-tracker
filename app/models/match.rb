class Match < ApplicationRecord
  LIVE_STATUSES = %w[1H HT 2H ET LIVE].freeze
  STATUS_DISPLAY = {
    "NS" => "—",
    "1H" => "1T'",
    "HT" => "MT",
    "2H" => "2T'",
    "ET" => "ET",
    "FT" => "FT",
    "LIVE" => "LIVE",
  }.freeze

  has_many :predictions, dependent: :destroy
  has_many :participants, through: :predictions

  validates :home_team, :away_team, :match_number, :matchday, presence: true
  validates :match_number, uniqueness: { scope: :matchday }

  after_update :refresh_prediction_points, if: :scores_changed?

  def result_set?
    home_score.present? && away_score.present?
  end

  def live?
    LIVE_STATUSES.include?(status)
  end

  def status_display
    STATUS_DISPLAY[status] || status.presence || "—"
  end

  private

  def scores_changed?
    (saved_change_to_home_score? || saved_change_to_away_score?) &&
      home_score.present? &&
      away_score.present?
  end

  def refresh_prediction_points
    predictions.find_each(&:refresh_points!)
  end
end
