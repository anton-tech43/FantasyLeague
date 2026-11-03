#!/usr/bin/env bash
# pre-commit-secret-scan.sh
# Block any commit that contains a Supabase JWT (legacy anon/service_role)
# or a new-model secret key in staged files.
#
# Install:
#   ln -s ../../scripts/pre-commit-secret-scan.sh .git/hooks/pre-commit
#   chmod +x .git/hooks/pre-commit
#
# Or, for the worktree:
#   cp scripts/pre-commit-secret-scan.sh .git/hooks/pre-commit
#   chmod +x .git/hooks/pre-commit
#
# What it catches:
#   - eyJhbGciOi*   — JWT header prefix (legacy Supabase keys begin here)
#   - sb_secret_*   — new-model secret key (the one you must never leak)
#   - sk-ant-*      — Anthropic API key
#   - -----BEGIN ... PRIVATE KEY----- — the APNs .p8 and any PEM key
#   - postgres://user:<password>@ — SUPABASE_DB_URL with its password
#   - blt_*         — Blotato API key
#   - 80 hex chars  — the cron key's shape (openssl rand -hex 40)
#   - 32 hex chars after an API-Football key name or header
#   The two hex shapes are checked in text files outside image and lock
#   assets only: photo-placeholder MD5s and asset hashes are hex too.
#   Self-test: scripts/test-pre-commit-secret-scan.sh
#
# What it ALLOWS (safe by design):
#   - sb_publishable_* — new-model publishable key, designed to be in the
#                       iOS app source. Not a secret.
#
# Where it scans:
#   - Only staged files (the ones about to be committed)
#   - Skips files under .gitignore (so Configuration.xcconfig with the
#     real publishable key never trips it, since that file is gitignored)
#
# Background:
# A leak of the legacy service_role JWT in committed migrations
# (015/016/017) on 2026-05-11 forced a full key rotation. This hook
# exists so a tired-future-Anton doesn't repeat the mistake.

set -euo pipefail

# Patterns that must NEVER appear in committed source.
# Use POSIX extended regex syntax (compatible with `git grep -E`).
PATTERNS=(
  "eyJhbGciOi[A-Za-z0-9_-]{8,}"                      # JWT header (legacy Supabase keys)
  "sb_secret_[A-Za-z0-9_-]{8,}"                      # New-model secret key
  "sk-ant-[A-Za-z0-9_-]{20,}"                        # Anthropic
  "-----BEGIN [A-Z ]*PRIVATE KEY-----"               # APNs .p8 / PEM
  "postgres(ql)?://[^:@/[:space:]]+:[^@[:space:]<>\$[{*]+@"  # DB URL with a password (not a <placeholder>)
  "blt_[A-Za-z0-9+/=_-]{16,}"                        # Blotato
)
# Hex shapes: only in text files that are not image/lock assets.
HEX_PATTERNS=(
  "(^|[^0-9a-fA-F])[0-9a-f]{80}([^0-9a-fA-F]|\$)"    # cron key (openssl rand -hex 40)
  "(x-apisports-key|API_FOOTBALL_KEY|APISPORTS_KEY)[\"']?[[:space:]]*[:=][[:space:]]*[\"']?[0-9a-f]{32}"  # API-Football
)
HEX_EXCLUDES=(
  ":(exclude,glob)**/*.xcassets/**" ":(exclude,glob)**/*.svg" ":(exclude,glob)**/*.lock"
  ":(exclude,glob)**/Package.resolved" ":(exclude,glob)**/*.pbxproj"
)

# Staged files, NUL-separated so a path with spaces stays one path (it used
# to split into pathspecs that matched nothing, and the scan passed).
# --diff-filter=d excludes deletions.
staged_files=()
while IFS= read -r -d '' f; do staged_files+=("$f"); done \
  < <(git diff --cached --name-only -z --diff-filter=d)

if (( ${#staged_files[@]} == 0 )); then
  exit 0
fi

found=0

scan() {
  local pattern=$1; shift
  # `git grep --cached` scans the index, not the working tree, so we never
  # block on edits not being committed. -I skips binary blobs. A git grep
  # error (exit > 1) must fail the commit, not pass it silently.
  local matches rc=0
  matches=$(git grep --cached -I -n -E -e "$pattern" -- "$@") || rc=$?
  if (( rc > 1 )); then
    echo "ERROR: secret scan could not run git grep (exit $rc)" >&2
    found=1
    return
  fi
  if [[ -n "$matches" ]]; then
    echo "ERROR: committed file contains a secret-like pattern" >&2
    echo "  pattern: $pattern" >&2
    # Show where, never the value.
    echo "$matches" | cut -d: -f1,2 | head -10 | sed 's/^/    /' >&2
    echo "" >&2
    echo "If this is intentional (e.g. a public sb_publishable_ key) please" >&2
    echo "verify it's not a secret. If it's a leak, abort the commit and" >&2
    echo "rotate the key before re-committing." >&2
    echo "" >&2
    found=1
  fi
}

for pattern in "${PATTERNS[@]}"; do
  scan "$pattern" "${staged_files[@]}"
done
for pattern in "${HEX_PATTERNS[@]}"; do
  scan "$pattern" "${staged_files[@]}" "${HEX_EXCLUDES[@]}"
done

if (( found )); then
  exit 1
fi

exit 0
