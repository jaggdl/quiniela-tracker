class PolymarketService
  require "net/http"
  require "json"

  GAMMA_URL = "https://gamma-api.polymarket.com".freeze
  SERIES_ID = "11433".freeze

  POLYMARKET_TEAM_MAP = {
    "Mexico" => "MÉXICO", "South Africa" => "SUDAFRICA",
    "Korea Republic" => "COREA", "Czechia" => "REP. CHECA",
    "Canada" => "CANADA", "Bosnia-Herzegovina" => "BOSNIA",
    "United States" => "ESTADOS UNIDOS", "Paraguay" => "PARAGUAY",
    "Brazil" => "BRASIL", "Morocco" => "MARRUECOS",
    "Qatar" => "CATAR", "Switzerland" => "SUIZA",
    "Haiti" => "HAITI", "Scotland" => "ESCOCIA",
    "Germany" => "ALEMANIA", "Curaçao" => "CURAZAO",
    "Côte d'Ivoire" => "COSTA DE MARFIL", "Ecuador" => "ECUADOR",
    "Netherlands" => "PAISES BAJOS", "Japan" => "JAPÓN",
    "Australia" => "AUSTRALIA", "Türkiye" => "TURQUIA",
    "Belgium" => "BELGICA", "Egypt" => "EGIPTO",
    "Saudi Arabia" => "ARABIA SAUDITA", "Uruguay" => "URUGUAY",
    "Spain" => "ESPAÑA", "Cabo Verde" => "CABO VERDE",
    "Sweden" => "SUECIA", "Tunisia" => "TUNEZ",
    "France" => "FRANCIA", "Senegal" => "SENEGAL",
    "Iraq" => "IRAK", "Norway" => "NORUEGA",
    "Argentina" => "ARGENTINA", "Algeria" => "ARGELIA",
    "Austria" => "AUSTRIA", "Jordan" => "JORDANIA",
    "Portugal" => "PORTUGAL", "DR Congo" => "CONGO",
    "England" => "INGLATERRA", "Croatia" => "CROACIA",
    "Ghana" => "GHANA", "Panama" => "PANAMA",
    "Colombia" => "COLOMBIA", "Uzbekistan" => "UZBEKISTAN",
    "IR Iran" => "IRAN", "New Zealand" => "NUEVA ZELANDA",
    "Italy" => "ITALIA",
  }.freeze

  ResultProbabilities = Data.define(:home_win, :draw, :away_win)

  def fetch
    events = fetch_events
    return {} if events.empty?

    result = {}
    events.each do |event|
      next if event["closed"]
      next unless event["markets"].is_a?(Array) && event["markets"].size == 3

      match = find_db_match(event)
      next unless match

      probs = extract_probabilities(event, event["markets"])
      next unless probs

      result[match.id] = probs
    end

    result
  end

  def fetch_events
    uri = URI("#{GAMMA_URL}/events?series_id=#{SERIES_ID}&limit=200")
    response = Net::HTTP.get(uri)
    JSON.parse(response)
  rescue StandardError => e
    Rails.logger.error("PolymarketService: #{e.message}")
    []
  end

  def find_db_match(event)
    title = event["title"] || ""
    parts = title.split(" vs. ")
    return nil unless parts.length == 2

    db_home = POLYMARKET_TEAM_MAP[parts[0].strip]
    db_away = POLYMARKET_TEAM_MAP[parts[1].strip]
    return nil unless db_home && db_away

    match = Match.find_by(home_team: db_home, away_team: db_away)
    return match if match

    Match.find_by(home_team: db_away, away_team: db_home)
  end

  private

  def extract_probabilities(event, markets)
    title = event["title"] || ""
    parts = title.split(" vs. ")
    home_name = parts[0]&.strip

    home_price = nil
    away_price = nil
    draw_price = nil

    markets.each do |m|
      question = m["question"] || ""
      prices = parse_prices(m["outcomePrices"])
      next unless prices && prices.length == 2
      yes_price = prices[0]

      if question.include?("end in a draw")
        draw_price = yes_price
      elsif home_name && question.include?(home_name)
        home_price = yes_price
      else
        away_price = yes_price
      end
    end

    return nil unless home_price && away_price && draw_price

    total = home_price + away_price + draw_price
    return nil if total.zero?

    ResultProbabilities.new(
      home_win: (home_price / total).round(4),
      draw: (draw_price / total).round(4),
      away_win: (away_price / total).round(4)
    )
  end

  def parse_prices(prices_str)
    return nil if prices_str.nil?
    JSON.parse(prices_str).map(&:to_f)
  rescue JSON::ParserError
    nil
  end
end
