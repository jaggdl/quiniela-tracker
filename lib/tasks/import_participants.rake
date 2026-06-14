require "csv"
require "net/http"
require "json"

namespace :import do
  desc "Import participants and predictions from CSV"
  task :participants, [:csv_path] => :environment do |_t, args|
    csv_path = args[:csv_path] || "~/Documents/Obsidian Vault/quiniela/participantes.csv"
    csv_path = File.expand_path(csv_path)

    unless File.exist?(csv_path)
      puts "File not found: #{csv_path}"
      exit 1
    end

    csv = CSV.read(csv_path, encoding: "utf-8")
    header = csv[0]

    match_pairs = parse_matches_from_header(header)

    ActiveRecord::Base.transaction do
      match_pairs.each_with_index do |(home_team, away_team), index|
        match_number = index + 1
        matchday = ((match_number - 1) / 24) + 1

        Match.find_or_create_by!(matchday: matchday, match_number: match_number) do |m|
          m.home_team = home_team
          m.away_team = away_team
        end
      end

      count = 0
      csv[3..].each do |row|
        next if row[2].nil? || row[2].strip.empty?
        next if row[4].nil? || row[5].nil?
        next unless row[4].to_s.match?(/^\d+$/) && row[5].to_s.match?(/^\d+$/)

        name = row[2].strip

        participant = Participant.find_or_create_by!(name: name)

        matches = Match.order(:matchday, :match_number).all

        (0...72).each do |i|
          col = 4 + (i * 3)
          home_score = row[col].to_i
          away_score = row[col + 1].to_i
          points = row[col + 2].to_i

          match = matches[i]
          next unless match

          pred = Prediction.find_or_initialize_by(participant: participant, match: match)
          pred.update!(home_score: home_score, away_score: away_score, points: points)
        end

        count += 1
        puts "Imported: #{name}"
      end

      puts ""
      puts "Done. Imported #{count} participants into #{match_pairs.length} matches."
    end
  end

  desc "Fetch and update match results from TheSportsDB API"
  task fetch_results: :environment do
    api_url = "https://www.thesportsdb.com/api/v1/json/123/eventsseason.php?id=4429&s=2026"
    uri = URI(api_url)
    response = Net::HTTP.get(uri)
    data = JSON.parse(response)
    events = data["events"] || []

    updated = 0

    events.each do |event|
      api_home = event["strHomeTeam"]
      api_away = event["strAwayTeam"]

      match = find_match(api_home, api_away)

      unless match
        puts "Skipping: #{api_home} vs #{api_away} — no match found in DB"
        next
      end

      attrs = { status: event["strStatus"] || "NS" }
      if event["intHomeScore"].present? && event["intAwayScore"].present?
        attrs[:home_score] = event["intHomeScore"]
        attrs[:away_score] = event["intAwayScore"]
      end

      match.update!(attrs)
      score_str = match.result_set? ? " #{match.home_score}-#{match.away_score}" : " ?-?"
      puts "Updated: #{match.home_team}#{score_str} #{match.away_team} (#{match.status})"
      updated += 1
    end

    puts ""
    puts "Done. Updated #{updated} match results."
  end

  TEAM_NAME_MAP = {
    "Mexico" => "MÉXICO",
    "South Africa" => "SUDAFRICA",
    "South Korea" => "COREA",
    "Czech Republic" => "REP. CHECA",
    "Canada" => "CANADA",
    "Bosnia-Herzegovina" => "BOSNIA",
    "USA" => "ESTADOS UNIDOS",
    "Paraguay" => "PARAGUAY",
    "Brazil" => "BRASIL",
    "Morocco" => "MARRUECOS",
    "Qatar" => "CATAR",
    "Switzerland" => "SUIZA",
    "Haiti" => "HAITI",
    "Scotland" => "ESCOCIA",
    "Germany" => "ALEMANIA",
    "Curaçao" => "CURAZAO",
    "Ivory Coast" => "COSTA DE MARFIL",
    "Ecuador" => "ECUADOR",
    "Netherlands" => "PAISES BAJOS",
    "Japan" => "JAPÓN",
    "Australia" => "AUSTRALIA",
    "Turkey" => "TURQUIA",
    "Belgium" => "BELGICA",
    "Egypt" => "EGIPTO",
    "Saudi Arabia" => "ARABIA SAUDITA",
    "Uruguay" => "URUGUAY",
    "Spain" => "ESPAÑA",
    "Cape Verde" => "CABO VERDE",
    "Sweden" => "SUECIA",
    "Tunisia" => "TUNEZ",
    "France" => "FRANCIA",
    "Senegal" => "SENEGAL",
    "Iraq" => "IRAK",
    "Norway" => "NORUEGA",
    "Argentina" => "ARGENTINA",
    "Algeria" => "ARGELIA",
    "Jordan" => "JORDANIA",
    "Portugal" => "PORTUGAL",
    "Congo" => "CONGO",
    "England" => "INGLATERRA",
    "Croatia" => "CROACIA",
    "Ghana" => "GHANA",
    "Panama" => "PANAMA",
    "Colombia" => "COLOMBIA",
    "Uzbekistan" => "UZBEKISTAN",
    "Austria" => "AUSTRIA",
    "Iran" => "IRAN",
    "New Zealand" => "NUEVA ZELANDA",
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
  }.freeze

  def team_name_for(api_name)
    TEAM_NAME_MAP[api_name] || api_name.upcase
  end

  def find_match(home, away)
    db_home = team_name_for(home)
    db_away = team_name_for(away)

    home_variants = DB_TEAM_VARIANTS[db_home] || [db_home]
    away_variants = DB_TEAM_VARIANTS[db_away] || [db_away]

    home_variants.product(away_variants).each do |h, a|
      match = Match.find_by(home_team: h, away_team: a)
      return match if match
    end

    Match.find_by(home_team: db_away, away_team: db_home)
  end

  def parse_matches_from_header(header)
    pairs = []
    i = 4

    while i < header.length
      t1 = (header[i] || "").strip
      t2 = (header[i + 1] || "").strip if i + 1 < header.length

      break if t1.empty? || t2.empty?
      break if t1 == "PTS."

      pairs << [t1, t2]
      i += 2

      if i < header.length && (header[i] || "").strip.empty?
        i += 1
      end
    end

    if pairs.length != 72
      puts "Warning: expected 72 matches, found #{pairs.length}"
    end

    pairs
  end
end
