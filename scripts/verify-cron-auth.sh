#!/usr/bin/env bash
# verify-cron-auth.sh
# Confirm the pg_cron Vault key is in a shape the Supabase Edge Function
# gateway will accept. Run this AFTER any Vault update, or as part of
# any deploy that touches `vault.secrets` rows.
#
# Exits 0 if everything is healthy, non-zero otherwise.
#
# Usage:
#   ./scripts/verify-cron-auth.sh
#
# Requires:
#   - backend/.env with SUPABASE_DB_URL set
#   - psql installed (brew install libpq + add to PATH)
#
# See:
#   - IOS_GOTCHAS.md #14 for the JWT-shape rule
#   - IMPLEMENTATION_PROGRESS.md Phase 27.3 + Lesson 56-57 for context.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${REPO_ROOT}/backend/.env"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "❌ ${ENV_FILE} not found. This script needs SUPABASE_DB_URL." >&2
    exit 1
fi

DB_URL="$(grep '^SUPABASE_DB_URL=' "$ENV_FILE" | cut -d= -f2-)"
if [[ -z "$DB_URL" ]]; then
    echo "❌ SUPABASE_DB_URL not in ${ENV_FILE}. See README.md setup." >&2
    exit 1
fi

# Add libpq to PATH if it's installed via brew but not in the default PATH.
if ! command -v psql >/dev/null && [[ -x "/opt/homebrew/opt/libpq/bin/psql" ]]; then
    export PATH="/opt/homebrew/opt/libpq/bin:${PATH}"
fi

# -----------------------------------------------------------------------------
# Check 1: Vault has the expected secret name
# -----------------------------------------------------------------------------
VAULT_PRESENT=$(psql "$DB_URL" -At -c \
    "SELECT EXISTS (SELECT 1 FROM vault.secrets WHERE name = 'cron_service_key');")
if [[ "$VAULT_PRESENT" != "t" ]]; then
    echo "❌ Vault.secrets does NOT contain 'cron_service_key'." >&2
    echo "   Crons that use get_cron_service_key() will silently fail." >&2
    exit 1
fi
echo "✓ Vault entry 'cron_service_key' exists."

# -----------------------------------------------------------------------------
# Check 2: SECURITY DEFINER accessor exists
# -----------------------------------------------------------------------------
ACCESSOR_PRESENT=$(psql "$DB_URL" -At -c "
SELECT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'get_cron_service_key'
);")
if [[ "$ACCESSOR_PRESENT" != "t" ]]; then
    echo "❌ public.get_cron_service_key() function not found." >&2
    echo "   Apply migration 020." >&2
    exit 1
fi
echo "✓ get_cron_service_key() accessor exists."

# -----------------------------------------------------------------------------
# Check 3: KEY SHAPE — the May-17 catch
# -----------------------------------------------------------------------------
KEY_PREFIX=$(psql "$DB_URL" -At -c "SELECT LEFT(get_cron_service_key(), 3);")
KEY_LEN=$(psql "$DB_URL" -At -c "SELECT LENGTH(get_cron_service_key());")

if [[ "$KEY_PREFIX" != "eyJ" ]]; then
    echo "❌ Vault key is NOT JWT shape (prefix=${KEY_PREFIX}, len=${KEY_LEN})." >&2
    echo "   Supabase gateway will return 401 on every cron tick." >&2
    echo "   Fix: vault.update_secret() with the legacy service_role JWT from" >&2
    echo "   backend/.env (SUPABASE_SERVICE_ROLE_KEY). See IOS_GOTCHAS.md #14." >&2
    exit 1
fi
if [[ "$KEY_LEN" -lt 100 ]]; then
    echo "❌ Vault key length ${KEY_LEN} is too short for a JWT (expect ~219)." >&2
    exit 1
fi
echo "✓ Vault key is JWT shape (prefix=eyJ, len=${KEY_LEN})."

# -----------------------------------------------------------------------------
# Check 4: Recent HTTP responses — are cron calls actually succeeding?
# -----------------------------------------------------------------------------
RECENT_HTTP=$(psql "$DB_URL" -At -c "
SELECT FORMAT('%s/%s 200',
    COUNT(*) FILTER (WHERE status_code = 200),
    COUNT(*))
FROM net._http_response
WHERE created > NOW() - INTERVAL '15 minutes';
")
echo "✓ Last 15-min net._http_response: ${RECENT_HTTP}"

NON_200_LAST_15=$(psql "$DB_URL" -At -c "
SELECT COUNT(*)
FROM net._http_response
WHERE created > NOW() - INTERVAL '15 minutes' AND status_code != 200;
")
if [[ "$NON_200_LAST_15" -gt 0 ]]; then
    echo "⚠️  ${NON_200_LAST_15} non-200 responses in the last 15 minutes. Inspect:" >&2
    psql "$DB_URL" -c "
    SELECT id, status_code, LEFT(content::text, 80) AS body, created::timestamp AT TIME ZONE 'Europe/Stockholm' AS local_time
    FROM net._http_response
    WHERE created > NOW() - INTERVAL '15 minutes' AND status_code != 200
    ORDER BY id DESC LIMIT 5;
    "
    exit 1
fi

echo ""
echo "✅ Cron auth healthy. All checks passed."
