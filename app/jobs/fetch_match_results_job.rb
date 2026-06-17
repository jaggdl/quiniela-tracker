class FetchMatchResultsJob < ApplicationJob
  queue_as :default

  require "net/http"
  require "json"

  API_URL = "https://www.thesportsdb.com/api/v1/json/123/eventsround.php?id=4429&s=2026&r=".freeze

  TEAM_NAME_MAP = {
    "Mexico" => "MÉXICO", "South Africa" => "SUDAFRICA",
    "South Korea" => "COREA", "Czech Republic" => "REP. CHECA",
    "Canada" => "CANADA", "Bosnia-Herzegovina" => "BOSNIA",
    "USA" => "ESTADOS UNIDOS", "Paraguay" => "PARAGUAY",
    "Brazil" => "BRASIL", "Morocco" => "MARRUECOS",
    "Qatar" => "CATAR", "Switzerland" => "SUIZA",
    "Haiti" => "HAITI", "Scotland" => "ESCOCIA",
    "Germany" => "ALEMANIA", "Curaçao" => "CURAZAO",
    "Ivory Coast" => "COSTA DE MARFIL", "Ecuador" => "ECUADOR",
    "Netherlands" => "PAISES BAJOS", "Japan" => "JAPÓN",
    "Australia" => "AUSTRALIA", "Turkey" => "TURQUIA",
    "Belgium" => "BELGICA", "Egypt" => "EGIPTO",
    "Saudi Arabia" => "ARABIA SAUDITA", "Uruguay" => "URUGUAY",
    "Spain" => "ESPAÑA", "Cape Verde" => "CABO VERDE",
    "Sweden" => "SUECIA", "Tunisia" => "TUNEZ",
    "France" => "FRANCIA", "Senegal" => "SENEGAL",
    "Iraq" => "IRAK", "Norway" => "NORUEGA",
    "Argentina" => "ARGENTINA", "Algeria" => "ARGELIA",
    "Jordan" => "JORDANIA", "Portugal" => "PORTUGAL",
    "Congo" => "CONGO", "England" => "INGLATERRA",
    "Croatia" => "CROACIA", "Ghana" => "GHANA",
    "Panama" => "PANAMA", "Colombia" => "COLOMBIA",
    "Uzbekistan" => "UZBEKISTAN", "Austria" => "AUSTRIA",
    "Iran" => "IRAN", "New Zealand" => "NUEVA ZELANDA",
    "Italy" => "ITALIA",
  }.freeze

  DB_TEAM_VARIANTS = {
    "ALEMANIA" => %w[ALEMANIA ALEMANIS],
    "ALEMANIS" => %w[ALEMANIS ALEMANIA],
    "BELGICA" => %w[BELGICA BÉLGICA],
    "BÉLGICA" => %w[BÉLGICA BELGICA],
    "JAPON" => %w[JAPON JAPÓN],
    "JAPÓN" => %w[JAPÓN JAPON],
    "COSTA DE MARFIL" => ["COSTA DE MARFIL", "COSRTA DE MARFIL"],
    "COSRTA DE MARFIL" => ["COSRTA DE MARFIL", "COSTA DE MARFIL"],
    "AUSTRIA" => %w[AUSTRIA AUSTRALIA],
  }.freeze

  def perform
    changed = false

    (1..3).each do |round|
      uri = URI("#{API_URL}#{round}")
      response = Net::HTTP.get(uri)
      data = JSON.parse(response)
      events = data["events"] || []

      events.each do |event|
        match = find_match(event["strHomeTeam"], event["strAwayTeam"])
        next unless match

        attrs = { status: event["strStatus"] || "NS" }
        scores_present = event["intHomeScore"].present? && event["intAwayScore"].present?
        if scores_present
          attrs[:home_score] = event["intHomeScore"].to_i
          attrs[:away_score] = event["intAwayScore"].to_i
        end

        scores_changed = scores_present &&
          (match.home_score != attrs[:home_score] || match.away_score != attrs[:away_score])

        if match.status == "FT" && attrs[:status] != "FT"
          attrs.delete(:status)
        end

        status_changed = attrs.key?(:status) && match.status != attrs[:status]
        if status_changed || scores_changed
          match.update!(attrs)
          changed = true
        end
      end
    end

    changed = true if update_statuses_from_polymarket

    broadcast_leaderboard if changed
  end

  private

  def broadcast_leaderboard
    matches = Match.order(:matchday, :match_number)

    participants = Participant.includes(predictions: :match).to_a

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
      ["leaderboard_pts", pts_sorted, "pts"],
      ["leaderboard_win", win_sorted, "win"]
    ].each do |channel, sorted, sort|
      html = ApplicationController.render(
        partial: "participants/table",
        assigns: { sort: sort, rank_by_pts: rank_by_pts },
        locals: {
          matches: matches,
          participants: sorted,
          predictions_by_participant: predictions_by_participant,
          leader_points: leader_points,
          max_win_prob: max_win_prob
        }
      )

      Turbo::StreamsChannel.broadcast_replace_to(
        channel,
        target: "leaderboard-content",
        html: html
      )
    end
  end

  def team_name_for(api_name)
    TEAM_NAME_MAP[api_name] || api_name.upcase
  end

  def find_match(api_home, api_away)
    db_home = team_name_for(api_home)
    db_away = team_name_for(api_away)

    home_variants = DB_TEAM_VARIANTS[db_home] || [db_home]
    away_variants = DB_TEAM_VARIANTS[db_away] || [db_away]

    home_variants.product(away_variants).each do |h, a|
      match = Match.find_by(home_team: h, away_team: a)
      return match if match
    end

    Match.find_by(home_team: db_away, away_team: db_home)
  end

  def update_statuses_from_polymarket
    events = PolymarketService.new.fetch_events
    return false if events.empty?

    changed = false

    events.each do |event|
      next unless event["live"]

      match = PolymarketService.new.find_db_match(event)
      next unless match
      next if match.result_set?

      if match.status != "LIVE"
        match.update!(status: "LIVE")
        changed = true
      end
    end

    changed
  rescue StandardError => e
    Rails.logger.warn("update_statuses_from_polymarket failed: #{e.message}")
    false
  end
end
