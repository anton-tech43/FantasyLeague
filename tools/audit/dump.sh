#!/bin/bash
# Dump My Turn for every PL club on the booted simulator (DEBUG build installed).
#   tools/audit/dump.sh <dir> <label> [now-iso]     e.g. dump.sh /tmp/a now
#                                                         dump.sh /tmp/a after 2026-10-13T12:00:00Z
# -gdNow moves "now" (the after-the-match view and the roll to the next opponent).
DIR=${1:?dir}; LABEL=${2:?label}; NOW=${3:-}
mkdir -p "$DIR/dumps" "$DIR/logs"
TEAMS=$(cd "$(dirname "$0")/../.." && set -a && source backend/.env && set +a && /opt/homebrew/opt/libpq/bin/psql "$SUPABASE_DB_URL" -Atqc "select id from teams where league_id = 39 and is_active order by id")
for T in $TEAMS; do
  xcrun simctl terminate booted com.goaldigger.app 2>/dev/null; sleep 1
  EXTRA=(); [ -n "$NOW" ] && EXTRA=(-gdNow "$NOW")
  xcrun simctl launch --console-pty booted com.goaldigger.app -gdSkipATT -gdResetMyTurn -gdPresetTeam $T -gdTab 2 -gdMyTurnModule prep -gdAuditDump -gdAuditLabel $LABEL "${EXTRA[@]}" > "$DIR/logs/${T}_$LABEL.txt" 2>&1 &
  PID=$!; sleep 28; kill $PID 2>/dev/null
  C=$(xcrun simctl get_app_container booted com.goaldigger.app data)
  cp "$C/Documents/myturn-audit-$T-$LABEL.json" "$DIR/dumps/" 2>/dev/null && echo "$T ok" || echo "$T MISSING"
  grep -i "assert\|fatal" "$DIR/logs/${T}_$LABEL.txt" | head -2
done
