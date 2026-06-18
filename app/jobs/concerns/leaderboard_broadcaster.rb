module LeaderboardBroadcaster
  extend ActiveSupport::Concern

  private

  def broadcast_leaderboard
    matches = Match.order(:matchday, :match_number)
    match_results = matches.index_by(&:id).transform_values(&:result_set?)

    participants = Participant.select(:id, :name, :win_probability)
                              .includes(:predictions)
                              .to_a

    predictions_by_participant = participants.each_with_object({}) do |participant, hash|
      hash[participant.id] = participant.predictions.index_by(&:match_id)
    end

    leader_points = participants.map(&:total_points).max || 0
    max_win_prob = participants.map(&:win_probability).compact.max || 0.0

    rank_by_pts = {}
    pts_sorted = participants.sort_by { |p| [-p.total_points, p.name] }
    pts_sorted.each_with_index { |p, i| rank_by_pts[p.id] = i + 1 }

    win_sorted = participants.sort_by { |p| [-p.win_probability, p.name] }

    [
      ["leaderboard_pts", pts_sorted, "pts", false],
      ["leaderboard_win", win_sorted, "win", false],
      ["leaderboard_pts_admin", pts_sorted, "pts", true],
      ["leaderboard_win_admin", win_sorted, "win", true],
    ].each do |channel, sorted, sort, show_win|
      html = ApplicationController.render(
        partial: "participants/table",
        assigns: { sort: sort, rank_by_pts: rank_by_pts },
        locals: {
          matches: matches,
          participants: sorted,
          predictions_by_participant: predictions_by_participant,
          leader_points: leader_points,
          max_win_prob: max_win_prob,
          show_win: show_win,
          match_results: match_results
        }
      )

      Turbo::StreamsChannel.broadcast_replace_to(
        channel,
        target: "leaderboard-table",
        html: html
      )
    end
  end
end
