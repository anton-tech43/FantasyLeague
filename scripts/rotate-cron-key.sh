#!/usr/bin/env bash
# Rotate the shared cron credential (QA 2026-10-04, C1).
#
# The old value is a legacy service_role JWT that sits in the PUBLIC git
# history (migrations 006, 015-017). require-service-auth.ts accepts it as
# CRON_AUTH_KEY, so anyone can call every server-only Edge Function with it.
# "Legacy keys disabled" only stops PostgREST, not this string compare.
#
# Sets a fresh random value in BOTH places back to back (Edge secret
# CRON_AUTH_KEY + Vault cron_service_key, which pg_cron sends), then updates
# backend/.env's SUPABASE_SERVICE_ROLE_KEY, which holds the same value for
# manual ops curl. pg_cron may 401 for the few seconds between the two
# writes; match-watcher runs every minute and recovers on the next tick.
#
# Run from the repo root: ./scripts/rotate-cron-key.sh
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; source backend/.env; set +a
PSQL=/opt/homebrew/opt/libpq/bin/psql
REF=cwgpsmbunrocrofziqad

NEW=$(openssl rand -hex 40)
old_digest=$(printf %s "$SUPABASE_SERVICE_ROLE_KEY" | shasum -a 256 | cut -c1-10)

(cd backend && supabase secrets set CRON_AUTH_KEY="$NEW" --project-ref "$REF" >/dev/null)
"$PSQL" "$SUPABASE_DB_URL" -X -q -v ON_ERROR_STOP=1 -v new="$NEW" \
  -c "select vault.update_secret((select id from vault.secrets where name = 'cron_service_key'), :'new');" >/dev/null

# backend/.env: replace the old value in place (BSD sed).
sed -i '' "s|^SUPABASE_SERVICE_ROLE_KEY=.*|SUPABASE_SERVICE_ROLE_KEY=$NEW|" backend/.env

new_digest=$(printf %s "$NEW" | shasum -a 256 | cut -c1-10)
vault_digest=$("$PSQL" "$SUPABASE_DB_URL" -X -t -A -c \
  "select left(encode(sha256(decrypted_secret::bytea), 'hex'), 10) from vault.decrypted_secrets where name = 'cron_service_key'")
secret_digest=$(cd backend && supabase secrets list --project-ref "$REF" | awk '$1=="CRON_AUTH_KEY"{print substr($3,1,10)}')

echo "old   $old_digest"
echo "new   $new_digest"
echo "vault $vault_digest"
echo "edge  $secret_digest"
[ "$vault_digest" = "$new_digest" ] && [ "$secret_digest" = "$new_digest" ] \
  && echo "OK: both stores hold the new key" || { echo "MISMATCH: fix before the next cron tick"; exit 1; }

echo "Waiting 90s for the next match-watcher tick..."
sleep 90
"$PSQL" "$SUPABASE_DB_URL" -X -c \
  "select status_code, count(*) from net._http_response where created > now() - interval '90 seconds' group by 1;"
echo "Expect only 200s. Then ./scripts/verify-cron-auth.sh"
