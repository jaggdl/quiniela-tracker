module ParticipantsHelper
  LIVE_STATUSES = %w[1H HT 2H ET LIVE].freeze

  def prediction_css(prediction, match_results = nil)
    has_result = if match_results
      match_results[prediction.match_id]
    else
      prediction&.match&.result_set?
    end
    return "no-result" unless has_result

    case prediction.points
    when 3 then "exact"
    when 1 then "direction"
    else "miss"
    end
  end

  def match_css(match)
    "match-live" if match.live?
  end
end
