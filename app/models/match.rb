class Match < ApplicationRecord
  LIVE_STATUSES = %w[1H HT 2H ET LIVE].freeze
  STATUS_DISPLAY = {
    "NS" => "—",
    "1H" => "1H'",
    "HT" => "HT",
    "2H" => "2H'",
    "ET" => "ET",
    "FT" => "FT",
    "LIVE" => "LIVE",
  }.freeze

  has_many :predictions, dependent: :destroy
  has_many :participants, through: :predictions

  validates :home_team, :away_team, :match_number, :matchday, presence: true
  validates :match_number, uniqueness: { scope: :matchday }

  after_update :refresh_prediction_points, if: :scores_changed?
  after_commit :broadcast_leaderboard_update, if: :scores_changed?

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

  def broadcast_leaderboard_update
    matches = Match.order(:matchday, :match_number)
    participants = Participant.includes(predictions: :match)
                              .sort_by { |p| [-p.total_points, p.name] }
    predictions_by_participant = participants.each_with_object({}) do |p, h|
      h[p.id] = p.predictions.index_by(&:match_id)
    end
    leader_points = participants.first&.total_points || 0

    html = ApplicationController.render(
      partial: "participants/table",
      locals: {
        matches: matches,
        participants: participants,
        predictions_by_participant: predictions_by_participant,
        leader_points: leader_points
      }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      "leaderboard",
      target: "leaderboard-content",
      html: html
    )
  end
end
