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
  "eyJhbGciOi[A-Za-z0-9_-]{8,}"   # JWT header (legacy Supabase keys)
  "sb_secret_[A-Za-z0-9_-]{8,}"   # New-model secret key
)

# Get list of staged files. --diff-filter=d excludes deletions.
staged_files=$(git diff --cached --name-only --diff-filter=d)

if [[ -z "$staged_files" ]]; then
  exit 0
fi

found=0

for pattern in "${PATTERNS[@]}"; do
  # `git grep --cached` scans the index, not the working tree. Limits to
  # staged blobs so we never block on edits not being committed.
  matches=$(git grep --cached -n -E "$pattern" -- $staged_files 2>/dev/null || true)
  if [[ -n "$matches" ]]; then
    echo "ERROR: committed file contains a secret-like pattern" >&2
    echo "  pattern: $pattern" >&2
    echo "$matches" | head -10 | sed 's/^/    /' >&2
    echo "" >&2
    echo "If this is intentional (e.g. a public sb_publishable_ key) please" >&2
    echo "verify it's not a secret. If it's a leak, abort the commit and" >&2
    echo "rotate the key before re-committing." >&2
    echo "" >&2
    found=1
  fi
done

if (( found )); then
  exit 1
fi

exit 0
