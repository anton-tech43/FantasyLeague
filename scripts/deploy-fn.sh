#!/usr/bin/env bash
# deploy-fn.sh — deploy Edge Functions, but not while a match is being watched.
#
#   ./scripts/deploy-fn.sh match-watcher
#   ./scripts/deploy-fn.sh notification-sender matchday-reminder
#   ./scripts/deploy-fn.sh --during-match match-watcher   # you know why
#
# A deploy restarts the function. Mid-match, match-watcher's first-observation
# guard then misses the FT transition (RUNBOOK "fired_finished_at IS NULL",
# bug hunt O-C4). poll_leagues() is exactly the set of competitions
# match-watcher polls right now (kickoff -35 min to the final whistle), so any
# row there means a match is live or about to be: refuse.
#
# --no-verify-jwt is load-bearing: the cron key is a random secret, not a JWT
# (IOS_GOTCHAS.md §14). Functions deploy one at a time so a failure names
# which one and stops the rest.
set -euo pipefail
cd "$(dirname "$0")/.."

override=0
names=()
for a in "$@"; do
  case "$a" in
    --during-match) override=1 ;;
    -*) echo "unknown flag: $a" >&2; exit 2 ;;
    *) names+=("$a") ;;
  esac
done
[ ${#names[@]} -gt 0 ] || { echo "usage: $0 [--during-match] <function> [function...]" >&2; exit 2; }

for n in "${names[@]}"; do
  [ -d "backend/supabase/functions/$n" ] || { echo "no such function: backend/supabase/functions/$n" >&2; exit 2; }
done

# A failed check refuses too: not knowing is not the same as no match.
if ! live=$(./scripts/sql.sh -At -c "select count(*) from poll_leagues()"); then
  echo "could not read poll_leagues(); refusing. Re-run with --during-match if you must deploy now." >&2
  exit 1
fi
if [ "$live" != "0" ] && [ $override -eq 0 ]; then
  echo "poll_leagues() has $live row(s): a match is live or kicks off within 35 min." >&2
  ./scripts/sql.sh -c "select * from poll_leagues()" >&2 || true
  echo "Refusing to deploy. Wait for full time, or re-run with --during-match." >&2
  exit 1
fi
[ "$live" = "0" ] || echo "WARNING: deploying during a match (--during-match), $live poll_leagues row(s)." >&2

cd backend
for n in "${names[@]}"; do
  echo "== deploying $n"
  supabase functions deploy "$n" --project-ref cwgpsmbunrocrofziqad --no-verify-jwt
done
