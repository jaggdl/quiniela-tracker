module ParticipantsHelper
  LIVE_STATUSES = %w[1H HT 2H ET LIVE].freeze

  def prediction_css(prediction)
    return "no-result" unless prediction&.match&.result_set?

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
