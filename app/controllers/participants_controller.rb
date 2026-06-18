class ParticipantsController < ApplicationController
  def index
    @matches = Match.order(:matchday, :match_number)
    @show_win = cookies[:is_admin].present?
    @sort = params[:sort].presence_in(%w[pts win]) || "pts"
    @sort = "pts" unless @show_win

    participants = Participant.includes(predictions: :match).to_a
    pts_rank = participants.sort_by { |p| [-p.total_points, p.name] }
    @rank_by_pts = {}
    pts_rank.each_with_index { |p, i| @rank_by_pts[p.id] = i + 1 }

    @participants = participants.sort_by { |p| sort_value(p) }

    @leader_points = @participants.map(&:total_points).max || 0

    @max_win_prob = @participants.map(&:win_probability).compact.max || 0.0

    @predictions_by_participant = @participants.each_with_object({}) do |participant, hash|
      hash[participant.id] = participant.predictions.index_by(&:match_id)
    end
  end

  private

  def sort_value(p)
    case @sort
    when "win" then [-p.win_probability, p.name]
    else [-p.total_points, p.name]
    end
  end
end
