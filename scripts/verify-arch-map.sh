#!/usr/bin/env bash
# verify-arch-map.sh — does docs/system-map/ still describe this system?
#
# The map is 272 hand-written boxes. Hand-written facts rot: eighteen root
# documents here already carry a "historical" banner, and the map itself
# shipped with a wrong one — it said client-error-alert had no caller, while
# notification-sender was calling it on every APNs auth failure.
#
# So the map's verifiable half comes from scripts/arch-facts.sh, and this
# script holds the two together. It answers one question in both directions:
# does the map name something that no longer exists, and does the system
# contain something the map has never heard of?
#
#   ./scripts/verify-arch-map.sh          offline: facts.json vs the map
#   ./scripts/verify-arch-map.sh --live   also re-derive and diff the facts
#
# Offline mode needs no database, so gd-maintenance can run it in the cloud
# where port 5432 is blocked (MAINTENANCE.md §1).
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAP="$HERE/docs/system-map"
FACTS="$MAP/facts.json"
OVERRIDES="$MAP/status-overrides.json"
# Every file that can define or describe a box.
SRC=$(cat "$MAP"/data.js "$MAP"/model3.js "$MAP"/plain.js 2>/dev/null)

fails=0; checks=0
ok()   { printf '  \033[32mOK\033[0m    %s\n' "$1"; checks=$((checks+1)); }
bad()  { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; fails=$((fails+1)); checks=$((checks+1)); }
warn() { printf '  \033[33mWARN\033[0m  %s\n' "$1"; checks=$((checks+1)); }

[ -f "$FACTS" ] || { echo "no facts.json — run ./scripts/arch-facts.sh first"; exit 1; }
[ -n "$SRC" ]   || { echo "no map source in $MAP — that is the finding"; exit 1; }

AGE_DAYS=$(( ( $(date -u +%s) - $(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$(jq -r .generatedAt "$FACTS")" +%s 2>/dev/null \
            || date -u -d "$(jq -r .generatedAt "$FACTS")" +%s) ) / 86400 ))

echo
echo "── 1. THE MAP KNOWS EVERYTHING THAT EXISTS ───────────────"
# A new Edge function, cron job or content table that nobody drew is the most
# likely way this map goes quietly wrong.
miss=0
for n in $(jq -r '.edge[].name' "$FACTS"); do
  grep -q "$n" <<< "$SRC" || { bad "Edge function '$n' exists and no box mentions it"; miss=1; }
done
[ "$miss" = 0 ] && ok "all $(jq '.edge|length' "$FACTS") Edge functions appear in the map"

miss=0
for j in $(jq -r '.cron[].job' "$FACTS"); do
  grep -q "$j" <<< "$SRC" || { bad "cron job '$j' runs and no box mentions it"; miss=1; }
done
[ "$miss" = 0 ] && ok "all $(jq '.cron|length' "$FACTS") cron jobs appear in the map"

miss=0
for t in $(jq -r '.tables[].table' "$FACTS"); do
  grep -q "$t" <<< "$SRC" || { bad "table '$t' holds content and no box mentions it"; miss=1; }
done
[ "$miss" = 0 ] && ok "all $(jq '.tables|length' "$FACTS") content tables appear in the map"

echo
echo "── 2. THE MAP DOES NOT DESCRIBE THINGS THAT ARE GONE ─────"
# The other direction. A box naming a deleted function is worse than a missing
# box, because it reads as current.
gone=0
for n in $(grep -o 'backend/supabase/functions/[a-z-]*/' <<< "$SRC" | sed 's|.*functions/||;s|/||' | sort -u); do
  [ "$n" = "_shared" ] && continue
  [ -d "$HERE/backend/supabase/functions/$n" ] || { bad "the map describes '$n', which no longer exists"; gone=1; }
done
[ "$gone" = 0 ] && ok "every Edge function the map names is still on disk"

gone=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  # Panels cite a path relative to whichever root reads most naturally there,
  # so try each. Resolving against the repo root alone reported three live
  # Swift files as missing on this script's first run.
  found=0
  for root in "$HERE" "$HERE/ios/GoalDigger" "$HERE/backend" ""; do
    case "$f" in /Users/anton/goaldigger-routines/*) p="$f" ;; *) p="${root:+$root/}$f" ;; esac
    case "$f" in
      *\**) compgen -G "$p" >/dev/null 2>&1 && { found=1; break; } ;;
      *)    [ -e "$p" ] && { found=1; break; } ;;
    esac
  done
  [ "$found" = 1 ] || { bad "the map cites '$f' and nothing resolves it"; gone=1; }
done < <(grep -o '"[a-zA-Z0-9_./-]*\.\(ts\|sh\|swift\|md\|json\|py\|rb\|sql\)"' <<< "$SRC" \
         | tr -d '"' | grep '/' | sort -u)
[ "$gone" = 0 ] && ok "every file path the map cites resolves"

echo
echo "── 3. DORMANT MEANS DORMANT ──────────────────────────────"
# "Has a caller" is not the same as "can run". The overrides carry the four
# cases where those differ, and each must still name a gate that exists.
for n in $(jq -r 'keys[] | select(startswith("_") | not)' "$OVERRIDES"); do
  gf=$(jq -r --arg n "$n" '.[$n].gateFile' "$OVERRIDES")
  gt=$(jq -r --arg n "$n" '.[$n].gateText' "$OVERRIDES")
  if [ ! -f "$HERE/$gf" ]; then bad "override for '$n' points at $gf, which is gone"
  elif grep -qF "$gt" "$HERE/$gf"; then ok "override '$n' still rests on a real gate in $(basename "$gf")"
  else bad "override for '$n' claims '$gt' in $(basename "$gf") and it is not there any more"; fi
done

unexplained=0
for n in $(jq -r '.edge[] | select((.callers|length) == 0) | .name' "$FACTS"); do
  jq -e --arg n "$n" 'has($n)' "$OVERRIDES" >/dev/null && continue
  # The node's own status field, not a window around its name: the first
  # version matched across node boundaries and warned about five functions
  # the map already marks dormant.
  if grep -qE "l:\"$n\"" <<< "$SRC" && \
     grep -B4 -E "l:\"$n\"" <<< "$SRC" | grep -qE 's:"(dormant|paused)"'; then :
  else warn "'$n' has no caller at all — the map should say dormant, or say who runs it"; unexplained=1; fi
done
[ "$unexplained" = 0 ] && ok "every caller-less function is marked dormant or explained"

echo
echo "── 4. THE FACTS ARE NOT ANCIENT ──────────────────────────"
if [ "$AGE_DAYS" -gt 30 ]; then bad "facts.json is $AGE_DAYS days old — re-run ./scripts/arch-facts.sh"
elif [ "$AGE_DAYS" -gt 10 ]; then warn "facts.json is $AGE_DAYS days old"
else ok "facts.json is $AGE_DAYS days old"; fi
jq -e '.db' "$FACTS" >/dev/null || warn "facts.json was generated without a database — the live half is missing"

if [ "${1:-}" = "--live" ]; then
  echo
  echo "── 5. LIVE DIFF ──────────────────────────────────────────"
  TMP=$(mktemp); "$HERE/scripts/arch-facts.sh" --print > "$TMP" 2>/dev/null
  for k in edgeFunctions cronJobs migrations swiftFiles sharedModules routinePrompts rootDocs; do
    a=$(jq -r ".counts.$k" "$FACTS"); b=$(jq -r ".counts.$k" "$TMP")
    if [ "$a" = "$b" ]; then ok "$k: $a"
    else bad "$k: facts.json says $a, the system says $b — re-run ./scripts/arch-facts.sh and update the map"; fi
  done
  rm -f "$TMP"
fi

echo
echo "=========================================================="
if [ "$fails" -eq 0 ]; then echo " The map matches the system. $checks checks."
else echo " The map has drifted — $fails of $checks checks failed."; fi
echo "=========================================================="
exit "$fails"
