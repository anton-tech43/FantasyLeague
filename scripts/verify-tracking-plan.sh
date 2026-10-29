#!/usr/bin/env bash
# verify-tracking-plan.sh — do the app, the RPC and docs/TRACKING_PLAN.md
# name the same events?
#
# Three lists must agree: AnalyticsEvent in the app, the `allowed` array in
# log_events (the newest migration that defines it), and the event tables in
# the plan. An event the app sends that the RPC does not know is refused and
# silently dropped by the phone; an event the plan names that the app never
# sends is a question nobody is answering. Same shape as verify-push-rules.sh.
#
# Read-only. No network, no database. Exit 0 = they agree.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SWIFT="$ROOT/ios/GoalDigger/Services/Analytics.swift"
DOC="$ROOT/docs/TRACKING_PLAN.md"
MIG=$(grep -l "FUNCTION public.log_events" "$ROOT"/backend/supabase/migrations/*.sql | sort | tail -1)

fails=0
ok()  { printf '  \033[32mOK\033[0m    %s\n' "$1"; }
bad() { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; fails=$((fails+1)); }

app=$(sed -n '/^enum AnalyticsEvent/,/^}/p' "$SWIFT" | grep -oE '= "[a-z_]+"' | tr -d '="' | tr -d ' ' | sort -u)
rpc=$(sed -n '/allowed CONSTANT text\[\]/,/\];/p' "$MIG" | grep -oE "'[a-z_]+'" | tr -d "'" | sort -u)
doc=$(grep -oE '^\| `[a-z_]+`' "$DOC" | grep -oE '[a-z_]+' | sort -u)

compare() { # $1 label-a, $2 list-a, $3 label-b, $4 list-b
  local missing
  missing=$(comm -23 <(echo "$2") <(echo "$4") | tr '\n' ' ')
  if [ -z "$missing" ]; then ok "every event in $1 is in $3"
  else bad "in $1 but not $3: $missing"; fi
}

echo
echo "── EVENT NAMES ($(basename "$MIG")) ─────────────────────"
[ -n "$app" ] || bad "no AnalyticsEvent cases found in $SWIFT"
[ -n "$rpc" ] || bad "no allow-list found in $MIG"
compare "the app" "$app" "the RPC" "$rpc"
compare "the RPC" "$rpc" "the app" "$app"
compare "the app" "$app" "the plan" "$doc"
compare "the plan" "$doc" "the app" "$app"

echo
echo "── EVERY EVENT IS SENT FROM SOMEWHERE ──────────────────"
missing=""
# The app logs with log(.case); the Notification Service Extension cannot
# link Analytics and names its one event as a string.
NSE="$ROOT/ios/GoalDigger/NotificationService"
while read -r e raw; do
  grep -rqE "log\(\.$e[,)]" "$ROOT/ios/GoalDigger" --include=*.swift \
    || grep -rqF "\"$raw\"" "$NSE" --include=*.swift \
    || missing="$missing $e"
done < <(sed -n '/^enum AnalyticsEvent/,/^}/p' "$SWIFT" | sed -nE 's/.*case ([a-zA-Z]+) = "([a-z_]+)".*/\1 \2/p')
if [ -z "$missing" ]; then ok "every case has a call site"; else bad "never logged:$missing"; fi

echo
if [ "$fails" -eq 0 ]; then echo " All agree."; else echo " $fails disagreement(s)."; fi
exit $((fails > 0))
