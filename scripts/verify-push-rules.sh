#!/usr/bin/env bash
# verify-push-rules.sh — does PUSH_RULES.md still describe the code?
#
# Eighteen root documents in this repo carry a "historical" banner because they
# stopped matching the code and nothing noticed. A page about what may interrupt
# a user cannot be allowed to drift that way, so this reads the rules out of the
# source and fails if the page has not kept up.
#
# Read-only. No network, no database, no writes. Exit 0 = they agree.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOC="$ROOT/PUSH_RULES.md"
ROUTINES="${GOALDIGGER_ROUTINES:-/Users/anton/goaldigger-routines}"
FN="$ROOT/backend/supabase/functions"

fails=0; checks=0
ok()   { printf '  \033[32mOK\033[0m    %s\n' "$1"; checks=$((checks+1)); }
bad()  { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; fails=$((fails+1)); checks=$((checks+1)); }
skip() { printf '  \033[33mSKIP\033[0m  %s\n' "$1"; }

[ -f "$DOC" ] || { echo "PUSH_RULES.md is missing — that is the finding."; exit 1; }

echo
echo "── 1. EVERY SENDER IS DOCUMENTED ─────────────────────────"
# _shared/apns-client.ts is the only path to APNs, so importing it is the same
# question as "can this thing buzz her phone?".
while IFS= read -r f; do
  name=$(basename "$(dirname "$f")")
  if grep -q "$name" "$DOC"; then
    ok "$name is named in PUSH_RULES.md"
  else
    bad "$name imports apns-client.ts and PUSH_RULES.md has never heard of it"
  fi
done < <(grep -rl "apns-client" "$FN" --include=index.ts | sort)

echo
echo "── 2. THE LIVE-MATCH TIER FLOORS MATCH ───────────────────"
# push-tiers.ts holds one small map. Each number has a phrase in the table, and
# this is what catches someone widening a push by editing only the code.
TIERS="$FN/_shared/push-tiers.ts"
phrase_for() { case "$1" in 1) echo "every tier";; 2) echo "tier 2+";; 3) echo "tier 3";; *) echo "__tier_$1__";; esac; }
row_for()    { case "$1" in kickoff) echo '| \*\*Kickoff\*\*';; goal) echo '| \*\*A goal\*\*';;
                            ht) echo '| \*\*Half time\*\*';; et) echo '| \*\*Extra time\*\*';;
                            ft) echo '| \*\*Full time\*\*';; esac; }
for ev in kickoff goal ht et ft; do
  # awk, not sed: \+ and \? are GNU extensions and this also runs on BSD.
  n=$(awk -v ev="$ev" '/^const BASE/,/^};/ { if ($1 == ev ":") { gsub(/[^0-9]/, "", $2); print $2; exit } }' "$TIERS")
  if [ -z "$n" ]; then bad "could not read the tier floor for '$ev' out of push-tiers.ts"; continue; fi
  want=$(phrase_for "$n"); row=$(grep -m1 "$(row_for "$ev")" "$DOC" || true)
  if [ -z "$row" ]; then bad "no row for '$ev' in PUSH_RULES.md §1"
  elif grep -qF "$want" <<< "$row"; then ok "$ev is tier $n in code, and §1 says \"$want\""
  else bad "$ev is tier $n in push-tiers.ts, but §1 does not say \"$want\""; fi
done

NS="$FN/notification-sender/index.ts"
sb=$(grep -o 'item.type === "sunday_brief" ? [0-9]* : [0-9]*' "$NS" | grep -o '[0-9][0-9]*' | head -1)
sbrow=$(grep -m1 '| \*\*The Sunday brief\*\*' "$DOC" || true)
if [ -z "$sb" ]; then bad "could not read the content-type tier floor out of notification-sender"
elif grep -qF "$(phrase_for "$sb")" <<< "$sbrow"; then ok "the Sunday brief is tier $sb in code, and §1 agrees"
else bad "the Sunday brief is tier $sb in notification-sender, but §1 says otherwise"; fi

echo
echo "── 3. EVERY DOWNGRADE IS EXPLAINED ───────────────────────"
# The literal force_reason strings are what appears in the run log, so the page
# has to use the same words or it cannot be searched from a log line.
POST="$ROUTINES/post_news.sh"
if [ ! -f "$POST" ]; then
  skip "post_news.sh not found (set GOALDIGGER_ROUTINES to check the downgrades)"
else
  n=0
  while IFS= read -r reason; do
    [ -z "$reason" ] && continue
    n=$((n+1))
    if grep -qF "$reason" "$DOC"; then ok "\"$reason\""
    else bad "post_news.sh can downgrade for \"$reason\" and PUSH_RULES.md §3 does not say so"; fi
  done < <(awk 'match($0, /force_reason="[^"]*"/) {
               s = substr($0, RSTART + 14, RLENGTH - 15)
               if (s ~ /^\$\{/) sub(/^.*\}/, "", s)      # drop the ${force_reason}${force_reason:+, } prefix
               if (s != "") print s
             }' "$POST" | sort -u)
  [ "$n" -gt 0 ] && ok "found $n downgrade reasons in post_news.sh" || bad "found no downgrade reasons at all — did the block move?"
fi

echo
echo "=========================================================="
if [ "$fails" -eq 0 ]; then
  echo " PUSH_RULES.md matches the code. $checks checks."
else
  echo " PUSH_RULES.md is out of date — $fails of $checks checks failed."
  echo " Fix the page in the same change that moved the code."
fi
echo "=========================================================="
exit "$fails"
