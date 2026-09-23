-- 109_manager_photo_placeholders.sql
-- Thirty manager "photos" that are not photos.
--
-- QA pass 2026-09-23 (BUG_AUDIT_2026-09-23.md, B6) found 8 of the 20 active PL
-- clubs showing a broken image where the manager headshot goes, in two
-- different broken styles. The cause is the one DATA_SOURCES.md warns about in
-- capitals: **the photo CDNs never 404**. media.api-sports.io answers every
-- coach id with HTTP 200, and for an id it has no headshot for it answers with
-- a placeholder image, so nothing downstream can tell the difference.
--
-- Migration 085 asserted this CDN "serves a correct headshot even for the
-- coaches whose club record is stale". That was verified by resolving the coach
-- ID, not by looking at the image. Checked properly on 2026-09-23 — all 73
-- manager photos in team_pages fetched and hashed — the CDN serves four
-- distinct placeholder images:
--
--   f512b984f93ca6915dd623351b93b531   8624 B  grey silhouette, "NO PHOTO YET"
--   3e52d4ec4bb65b0a2019236c4dabd3fc  12934 B  dark shield with a slash
--   68ac0d5773da5ee81444ade70d89533d  29416 B  grey camera, "image not available"
--   0e3bde19a08632f2e893bc2a835598bc    678 B  stub served for an unknown id
--
-- 30 of the 73 are one of these: 8 PL clubs (brentford, crystal_palace, fulham,
-- hull, ipswich, liverpool, man_utd, sunderland — every one of them a manager
-- appointed in 2025/2026), 4 relegated clubs still holding a page, and 18
-- countries. The two styles she actually saw are the first three; the fourth is
-- what an unknown id returns and is here so the check is complete.
--
-- We do not have better photos for these managers, so the fix is to stop
-- claiming we do. With photo_url gone the app draws its own circular
-- silhouette, which is one consistent in-brand placeholder instead of two
-- off-brand broken ones. A real headshot can be dropped back in any time by
-- setting the column again.
--
-- Keyed on the URL, not the team id, so re-running it is a no-op and so a club
-- that changes manager to someone with a real photo is untouched.
--
-- Re-check (run it after every manager change, alongside the stale-data-audit
-- skill; see DATA_SOURCES.md → "Photos never 404"):
--   psql "$SUPABASE_DB_URL" -At -F'|' -c "SELECT team_id, content->'cards'->'manager'->>'photo_url' \
--     FROM team_pages WHERE content->'cards'->'manager'->>'photo_url' <> ''" \
--   | while IFS='|' read -r id url; do curl -s "$url" | md5 -q | \
--       grep -qE 'f512b984f93ca6915dd623351b93b531|3e52d4ec4bb65b0a2019236c4dabd3fc|68ac0d5773da5ee81444ade70d89533d|0e3bde19a08632f2e893bc2a835598bc' \
--       && echo "PLACEHOLDER $id $url"; done

BEGIN;

CREATE TEMP TABLE placeholder_photo(url text PRIMARY KEY) ON COMMIT DROP;
INSERT INTO placeholder_photo(url) VALUES
  ('https://media.api-sports.io/football/coachs/76.png'),
  ('https://media.api-sports.io/football/coachs/373.png'),
  ('https://media.api-sports.io/football/coachs/856.png'),
  ('https://media.api-sports.io/football/coachs/861.png'),
  ('https://media.api-sports.io/football/coachs/914.png'),
  ('https://media.api-sports.io/football/coachs/1552.png'),
  ('https://media.api-sports.io/football/coachs/1878.png'),
  ('https://media.api-sports.io/football/coachs/2108.png'),
  ('https://media.api-sports.io/football/coachs/2703.png'),
  ('https://media.api-sports.io/football/coachs/2721.png'),
  ('https://media.api-sports.io/football/coachs/2883.png'),
  ('https://media.api-sports.io/football/coachs/5832.png'),
  ('https://media.api-sports.io/football/coachs/6279.png'),
  ('https://media.api-sports.io/football/coachs/8214.png'),
  ('https://media.api-sports.io/football/coachs/10665.png'),
  ('https://media.api-sports.io/football/coachs/12856.png'),
  ('https://media.api-sports.io/football/coachs/16053.png'),
  ('https://media.api-sports.io/football/coachs/17636.png'),
  ('https://media.api-sports.io/football/coachs/21562.png'),
  ('https://media.api-sports.io/football/coachs/22538.png'),
  ('https://media.api-sports.io/football/coachs/25364.png'),
  ('https://media.api-sports.io/football/coachs/25679.png'),
  ('https://media.api-sports.io/football/coachs/25729.png'),
  ('https://media.api-sports.io/football/coachs/25762.png'),
  ('https://media.api-sports.io/football/coachs/25765.png'),
  ('https://media.api-sports.io/football/coachs/27707.png'),
  ('https://media.api-sports.io/football/coachs/28218.png'),
  ('https://media.api-sports.io/football/coachs/28220.png'),
  ('https://media.api-sports.io/football/coachs/28221.png'),
  ('https://media.api-sports.io/football/coachs/28250.png');

-- 1. The source of truth (mig 085's column).
UPDATE teams
   SET manager_photo_url = NULL,
       manager_verified_at = now()
 WHERE manager_photo_url IN (SELECT url FROM placeholder_photo);

-- 2. The pages the app actually reads. Deleted, not set to null: iOS treats a
--    missing key and a null the same, but team-page-generator spreads the
--    previous card forward, so a key left behind would be copied into every
--    future refresh.
UPDATE team_pages tp
   SET content = jsonb_set(
         tp.content, '{cards,manager}',
         (tp.content->'cards'->'manager') - 'photo_url', true),
       updated_at = now()
 WHERE tp.content->'cards'->'manager'->>'photo_url'
       IN (SELECT url FROM placeholder_photo);

COMMIT;

-- Verification:
--   SELECT count(*) FROM teams WHERE manager_photo_url IS NOT NULL;         -- 12
--   SELECT count(*) FROM team_pages
--    WHERE content->'cards'->'manager' ? 'photo_url';                       -- 43
