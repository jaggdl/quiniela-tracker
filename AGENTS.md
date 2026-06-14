# Quiniela Tracker — Project Context

Rails 8.1 app for tracking a World Cup 2026 "quiniela" leaderboard. Participants submit score predictions for each group stage match. Points are calculated automatically when actual match results are entered.

## Stack

- **Ruby 3.4.1**, **Rails 8.1.3**, **SQLite 3**
- **Propshaft** for assets, **Importmap** for JS, **Turbo/Stimulus**
- **Solid Queue** for background jobs (production recurring tasks)
- No frontend framework — server-rendered ERB views

## Database Schema

### `participants`
- `name` (string, not null) — participant's display name
- `position` (integer, nullable) — original CSV position
- No `total_points` column — computed via `predictions.sum(:points)`

### `matches`
- `home_team`, `away_team` (string, not null)
- `match_number` (integer, not null) — 1–72
- `matchday` (integer, not null) — 1, 2, or 3 (jornada). Each matchday has 24 matches.
- `home_score`, `away_score` (integer, nullable) — actual result, nil until set
- `status` (string) — from TheSportsDB API: `FT`, `NS`, `1H`, `2H`, `HT`, `ET`, `LIVE`
- Unique index on `[matchday, match_number]`

### `predictions`
- `participant_id`, `match_id` (FKs, not null)
- `home_score`, `away_score` (integer, not null) — participant's prediction
- `points` (integer, default 0) — 0, 1, or 3. Auto-calculated when match result changes.
- Unique index on `[participant_id, match_id]`

## Scoring Rules

```ruby
# Prediction.calc_points(actual_home, actual_away, pred_home, pred_away)
3  # exact score match
1  # correct result direction (win/loss/draw) but different score
0  # wrong or no match result set
```

## Key Behaviors

### Auto-recalculation
When a match's `home_score` or `away_score` changes AND both are present, `Match#refresh_prediction_points` fires via `after_update`, recalculating all predictions for that match. Scores set to nil do NOT trigger recalculation (prevents accidental data wipes).

### `Participant#total_points`
Computed method: `predictions.sum(:points)`. Not a database column. The controller orders by this using a SQL join + group + sum for efficiency.

### Team name mapping
The CSV uses Spanish team names (e.g., "ALEMANIA", "PAISES BAJOS", "ESTADOS UNIDOS"). The TheSportsDB API uses English names. `FetchMatchResultsJob` and the import rake task have a `TEAM_NAME_MAP` constant plus a `DB_TEAM_VARIANTS` hash for known typos/variants ("ALEMANIA"/"ALEMANIS", "BELGICA"/"BÉLGICA", "JAPON"/"JAPÓN", "COSTA DE MARFIL"/"COSRTA DE MARFIL").

## Routes

```
GET /up            => rails/health#show
GET /participants  => participants#index
GET /              => participants#index (root)
```

## Rake Tasks

### `import:participants`
Loads the CSV from `~/Documents/Obsidian Vault/quiniela/participantes.csv`. Creates/updates matches and participants with predictions. Each match in the CSV uses 3 columns: `home_score, away_score, points`. Skips summary rows (rows without numeric score data).

### `import:fetch_results`
Fetches events from TheSportsDB API (`eventsseason.php?id=4429&s=2026`), maps team names, and updates match scores and status. Safe to call frequently.

## Background Jobs

### `FetchMatchResultsJob`
Wraps the fetch logic from `import:fetch_results`. Configured in `config/recurring.yml` to run every minute in production via Solid Queue.

### Development cron
`bin/fetch_scores_loop` runs `rails import:fetch_results` in a bash loop every 60 seconds. Start it in a separate terminal during development.

## Important CSV Data Facts

- **108 participants** × **72 matches** = 7,776 predictions
- Matches are 3 jornadas (matchdays) of 24 matches each
- Match order: Jornada 1 (matches 1–24), Jornada 2 (25–48), Jornada 3 (49–72)
- The "TU MARCADOR" row (row 2) uses 3 columns per match (home, away, empty separator). Participant rows use 3 columns too (home_score, away_score, points_earned).
- Summary rows at the bottom (e.g., "Cuantos 3 Pts") have no actual predictions and are filtered out.

## View Details

- `app/views/participants/index.html.erb` — Leaderboard table with all 72 match columns
- Fixed left columns (#, name, pts) via sticky CSS; right columns scroll horizontally
- Color coding: green (`exact`, 3pts), yellow (`direction`, 1pt), red (`miss`, 0pts), gray (`no-result`)
- Live matches get red header column + pulsing badge with status (`2H'`, `1H'`)
- Helper `prediction_css(prediction)` in `ParticipantsHelper`
