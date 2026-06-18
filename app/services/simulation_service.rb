class SimulationService
  DEFAULT_ITERATIONS = 5000

  def initialize(iterations: DEFAULT_ITERATIONS)
    @iterations = iterations
  end

  def run
    matches = Match.order(:matchday, :match_number).to_a
    remaining = matches.reject(&:result_set?)
    completed_ids = matches.select(&:result_set?).map(&:id)

    participants = Participant.includes(:predictions).to_a
    return empty_probabilities(participants) if participants.empty?

    base_points = {}
    participants.each { |p| base_points[p.id] = p.total_points }

    return current_winner_probabilities(participants, base_points) if remaining.empty?

    polymarket_probs = PolymarketService.new.fetch

    distributions = build_distributions(remaining, polymarket_probs)

    pred_home, pred_away = flatten_predictions(participants, remaining)

    win_counts = run_simulation(
      participants, remaining, base_points,
      distributions, pred_home, pred_away
    )

    total = @iterations.to_f
    participants.each_with_object({}) do |p, h|
      h[p.id] = ((win_counts[p.id].to_f / total) * 100).round(1)
    end
  end

  private

  def build_distributions(remaining, polymarket_probs)
    remaining.each_with_object({}) do |match, h|
      preds = Prediction.where(match_id: match.id).pluck(:home_score, :away_score)
      counts = Hash.new(0.0)
      preds.each { |home, away| counts[[home, away]] += 1.0 }

      probs = polymarket_probs[match.id]
      if probs
        blend_polymarket!(counts, probs)
      end

      entries = counts.keys
      weights = entries.map { |k| counts[k] }
      h[match.id] = { entries: entries, weights: weights, total: weights.sum }
    end
  end

  def blend_polymarket!(counts, probs)
    home_scores = Hash.new(0.0)
    draw_scores = Hash.new(0.0)
    away_scores = Hash.new(0.0)

    counts.each do |(h, a), w|
      if h > a
        home_scores[[h, a]] = w
      elsif h == a
        draw_scores[[h, a]] = w
      else
        away_scores[[h, a]] = w
      end
    end

    home_total = home_scores.values.sum
    draw_total = draw_scores.values.sum
    away_total = away_scores.values.sum
    crowd_total = home_total + draw_total + away_total

    return if crowd_total.zero?

    home_crowd_pct = home_total / crowd_total
    draw_crowd_pct = draw_total / crowd_total
    away_crowd_pct = away_total / crowd_total

    counts.clear

    home_scores.each do |score, w|
      counts[score] = w * (probs.home_win / home_crowd_pct) if home_crowd_pct > 0
    end
    draw_scores.each do |score, w|
      counts[score] = w * (probs.draw / draw_crowd_pct) if draw_crowd_pct > 0
    end
    away_scores.each do |score, w|
      counts[score] = w * (probs.away_win / away_crowd_pct) if away_crowd_pct > 0
    end
  end

  def flatten_predictions(participants, remaining)
    match_ids = remaining.map(&:id)
    preds_by_participant = {}
    participants.each do |p|
      preds_by_participant[p.id] = p.predictions.index_by(&:match_id)
    end

    home = participants.map do |p|
      lookup = preds_by_participant[p.id]
      match_ids.map { |mid| lookup[mid]&.home_score || 0 }
    end

    away = participants.map do |p|
      lookup = preds_by_participant[p.id]
      match_ids.map { |mid| lookup[mid]&.away_score || 0 }
    end

    [home, away]
  end

  def run_simulation(participants, remaining, base_points, distributions, pred_home, pred_away)
    n_participants = participants.length
    n_matches = remaining.length

    dist_entries = remaining.map { |m| distributions[m.id][:entries] }
    dist_weights = remaining.map { |m| distributions[m.id][:weights] }
    dist_totals  = remaining.map { |m| distributions[m.id][:total] }

    win_counts = Hash.new(0.0)

    @iterations.times do
      sim_home = Array.new(n_matches)
      sim_away = Array.new(n_matches)

      n_matches.times do |mi|
        next if dist_totals[mi].zero?

        r = rand * dist_totals[mi]
        cum = 0
        entries = dist_entries[mi]
        weights = dist_weights[mi]
        weights.each_with_index do |w, ei|
          cum += w
          if r < cum
            sim_home[mi], sim_away[mi] = entries[ei]
            break
          end
        end
        sim_home[mi] ||= entries.last[0]
        sim_away[mi] ||= entries.last[1]
      end

      totals = Array.new(n_participants)
      max_pts = -1

      n_participants.times do |pi|
        total = base_points[participants[pi].id]
        nh = pred_home[pi]
        na = pred_away[pi]
        n_matches.times do |mi|
          ah = sim_home[mi]
          aa = sim_away[mi]
          next unless ah && aa

          ph = nh[mi]
          pa = na[mi]
          if ah == ph && aa == pa
            total += 3
          elsif (ah <=> aa) == (ph <=> pa)
            total += 1
          end
        end
        totals[pi] = total
        max_pts = total if total > max_pts
      end

      winners = []
      n_participants.times { |pi| winners << pi if totals[pi] == max_pts }
      share = 1.0
      winners.each { |pi| win_counts[participants[pi].id] += share }
    end

    win_counts
  end

  def empty_probabilities(participants)
    participants.each_with_object({}) { |p, h| h[p.id] = 0.0 }
  end

  def current_winner_probabilities(participants, base_points)
    max_pts = base_points.values.max || 0
    winners = base_points.select { |_, pts| pts == max_pts }.keys
    share = winners.any? ? (100.0 / winners.length).round(1) : 0.0
    participants.each_with_object({}) do |p, h|
      h[p.id] = winners.include?(p.id) ? share : 0.0
    end
  end

  def cannot_win_participants
    matches = Match.order(:matchday, :match_number).to_a
    remaining = matches.reject(&:result_set?)
    participants = Participant.includes(:predictions).to_a
    return Set.new if participants.empty?

    base_points = {}
    participants.each { |p| base_points[p.id] = p.total_points }

    if remaining.empty?
      max_pts = base_points.values.max || 0
      return Set.new(participants.reject { |p| base_points[p.id] == max_pts }.map(&:id))
    end

    preds_by_participant = participants.each_with_object({}) do |p, h|
      h[p.id] = p.predictions.each_with_object({}) do |pred, inner|
        inner[pred.match_id] = [pred.home_score, pred.away_score]
      end
    end

    remaining_ids = remaining.map(&:id)
    remaining_count = remaining_ids.length

    cannot_win = Set.new

    participants.each do |p|
      pid = p.id
      perfect_score = base_points[pid] + 3 * remaining_count

      beaten = false
      participants.each do |q|
        next if q.id == pid

        q_total = base_points[q.id]
        remaining_ids.each do |mid|
          p_pred = preds_by_participant[pid][mid]
          q_pred = preds_by_participant[q.id][mid]
          next if p_pred.nil? || q_pred.nil?

          if p_pred == q_pred
            q_total += 3
          elsif (p_pred[0] <=> p_pred[1]) == (q_pred[0] <=> q_pred[1])
            q_total += 1
          end
        end

        if q_total > perfect_score
          beaten = true
          break
        end
      end

      cannot_win << pid if beaten
    end

    cannot_win
  end
end
