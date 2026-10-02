#!/bin/bash
# Export the truth check.py reads: the latest raw API-Football payload per club
# and source, teams, players and team pages. Read only, $0 (no API calls).
#   tools/audit/export.sh <dir>
set -euo pipefail
OUT=${1:?usage: export.sh <dir>}; mkdir -p "$OUT"
cd "$(dirname "$0")/../.."
set -a; source backend/.env; set +a
q() { /opt/homebrew/opt/libpq/bin/psql "$SUPABASE_DB_URL" -Atqc "$1"; }
for src in api_football_fixtures_next api_football_fixtures_last api_football_standings api_football_squad api_football_predictions api_football_players_stats; do
  q "select coalesce(json_object_agg(team_id, data), '{}') from (select distinct on (team_id) team_id, data from raw_fetch_logs where source = '$src' order by team_id, fetched_at desc) r" > "$OUT/raw_$src.json"
done
q "select json_agg(t) from (select id, display_name, short_name, manager_name, api_football_id, league_id from teams) t" > "$OUT/raw_teams.json"
q "select json_agg(p) from (select team_id, api_player_id, name, number, position, minutes, goals, assists, appearances, starts from players) p" > "$OUT/raw_players.json"
q "select json_object_agg(team_id, content) from team_pages" > "$OUT/raw_pages.json"
cp tools/audit/standings_2025.json "$OUT/raw_standings_2025.json"
# The Premier League's own squad lists (the official-squads function's source).
mkdir -p "$OUT/official"
q "select id || ' ' || pl_squad_id from teams where pl_squad_id is not null" | while read id pl; do
  curl -sf "https://sdp-prem-prod.premier-league-prod.pulselive.com/api/v2/competitions/8/seasons/2026/teams/$pl/squad" > "$OUT/official/$id.json" || echo "official $id failed" >&2
done
echo "exported to $OUT"
