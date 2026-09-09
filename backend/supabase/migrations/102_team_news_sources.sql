-- 102_team_news_sources.sql
--
-- Where a club's news actually comes from, per club, with a trust tier.
--
-- Until now `fetch_news.sh` pulled twelve national feeds and asked the model to
-- find Sunderland inside them. Three of the twelve were rumour mills, nothing
-- was per club, and a promoted club got whatever the nationals happened to
-- write that day. This table is the per-club feed list, verified by curl on
-- 2026-09-09 (HTTP 200, parseable XML, newest pubDate inside seven days).
--
-- trust is the only column the guards read:
--   record — a fact may rest on this source alone (bbc, guardian, official,
--            and sky for anything that is not a transfer: Sky mixes confirmed
--            business with agent talk in the same feed)
--   colour — local papers and The Athletic. Real reporting, but a fact needs
--            two independent colour hosts, or it publishes as colour ("the
--            local press are saying") and never as a headline or a push.
--
-- Two per-feed item filters live here rather than in the script, because they
-- are properties of the feed:
--   reject_link_contains — BBC's 14 non-usable team feeds return four Sounds
--            audio items whose link contains /sounds/. A freshness check passes
--            and the content is worthless.
--   require_keyword — the Bournemouth Echo publishes one mixed sport feed.
--
-- Brentford and Fulham have no local paper (football.london's sections for them
-- are empty); they run on Sky + Guardian + BBC. See DATA_SOURCES.md for the
-- dead ends so nobody re-tries them.

CREATE TABLE IF NOT EXISTS team_news_sources (
  id                   serial PRIMARY KEY,
  -- NULL = league-wide (The Athletic). FK so a relegated club's rows go with it.
  team_id              text REFERENCES teams(id) ON DELETE CASCADE,
  name                 text NOT NULL,
  kind                 text NOT NULL CHECK (kind IN ('sky','guardian','bbc','official','local','athletic','national')),
  trust                text NOT NULL CHECK (trust IN ('record','colour')),
  url                  text NOT NULL UNIQUE,
  reject_link_contains text,
  require_keyword      text,
  verified_at          timestamptz,
  last_ok_at           timestamptz,
  last_status          integer,
  is_active            boolean NOT NULL DEFAULT true
);

CREATE INDEX IF NOT EXISTS idx_team_news_sources_active
  ON team_news_sources (team_id) WHERE is_active;

ALTER TABLE team_news_sources ENABLE ROW LEVEL SECURITY;

-- Service role only. Nothing in the app reads this; it is pipeline config, and
-- the routines reach it with the service key.
DROP POLICY IF EXISTS team_news_sources_service_all ON team_news_sources;
CREATE POLICY team_news_sources_service_all ON team_news_sources
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

GRANT ALL ON team_news_sources TO service_role;
GRANT USAGE, SELECT ON SEQUENCE team_news_sources_id_seq TO service_role;

COMMENT ON TABLE team_news_sources IS
  'Per-club RSS sources with a trust tier. Read by fetch_news.sh (club_rss) '
  'and verify_feeds.sh in goaldigger-routines. trust=record may carry a fact '
  'alone; trust=colour needs two independent hosts.';

-- verify_feeds.sh logs a feed that has been dead for seven days here.
ALTER TABLE pipeline_health DROP CONSTRAINT IF EXISTS pipeline_health_stage_check;
ALTER TABLE pipeline_health ADD CONSTRAINT pipeline_health_stage_check
  CHECK (stage = ANY (ARRAY[
    'fetch','generate','review','safety_review','publish','live_brief_fire',
    'matchday_fire','routine_post','apns_send','cron_invoke','morning_push',
    'starting_xi_fire','consequence_fire','content_audit','watch','page_refresh',
    'news_feeds'
  ]));

-- Seed. Idempotent: re-running refreshes everything except the observed
-- last_ok_at/last_status, which belong to verify_feeds.sh.
INSERT INTO team_news_sources
  (team_id, name, kind, trust, url, reject_link_contains, require_keyword, verified_at)
VALUES
  ('arsenal', 'Sky Sports Arsenal', 'sky', 'record', 'https://www.skysports.com/rss/11670', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('aston_villa', 'Sky Sports Aston Villa', 'sky', 'record', 'https://www.skysports.com/rss/11677', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('bournemouth', 'Sky Sports Bournemouth', 'sky', 'record', 'https://www.skysports.com/rss/11743', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('brentford', 'Sky Sports Brentford', 'sky', 'record', 'https://www.skysports.com/rss/11748', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('brighton', 'Sky Sports Brighton', 'sky', 'record', 'https://www.skysports.com/rss/11741', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('chelsea', 'Sky Sports Chelsea', 'sky', 'record', 'https://www.skysports.com/rss/11668', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('coventry', 'Sky Sports Coventry City', 'sky', 'record', 'https://www.skysports.com/rss/11710', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('crystal_palace', 'Sky Sports Crystal Palace', 'sky', 'record', 'https://www.skysports.com/rss/11706', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('everton', 'Sky Sports Everton', 'sky', 'record', 'https://www.skysports.com/rss/11671', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('fulham', 'Sky Sports Fulham', 'sky', 'record', 'https://www.skysports.com/rss/11681', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('hull', 'Sky Sports Hull City', 'sky', 'record', 'https://www.skysports.com/rss/11714', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('ipswich', 'Sky Sports Ipswich Town', 'sky', 'record', 'https://www.skysports.com/rss/11707', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('leeds', 'Sky Sports Leeds United', 'sky', 'record', 'https://www.skysports.com/rss/11715', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('liverpool', 'Sky Sports Liverpool', 'sky', 'record', 'https://www.skysports.com/rss/11669', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('man_city', 'Sky Sports Manchester City', 'sky', 'record', 'https://www.skysports.com/rss/11679', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('man_utd', 'Sky Sports Manchester United', 'sky', 'record', 'https://www.skysports.com/rss/11667', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('newcastle', 'Sky Sports Newcastle', 'sky', 'record', 'https://www.skysports.com/rss/11678', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('nottm_forest', 'Sky Sports Nottingham Forest', 'sky', 'record', 'https://www.skysports.com/rss/11727', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('spurs', 'Sky Sports Tottenham', 'sky', 'record', 'https://www.skysports.com/rss/11675', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('sunderland', 'Sky Sports Sunderland', 'sky', 'record', 'https://www.skysports.com/rss/11695', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('arsenal', 'Guardian Arsenal', 'guardian', 'record', 'https://www.theguardian.com/football/arsenal/rss', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('aston_villa', 'Guardian Aston Villa', 'guardian', 'record', 'https://www.theguardian.com/football/aston-villa/rss', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('bournemouth', 'Guardian Bournemouth', 'guardian', 'record', 'https://www.theguardian.com/football/bournemouth/rss', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('brentford', 'Guardian Brentford', 'guardian', 'record', 'https://www.theguardian.com/football/brentford/rss', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('brighton', 'Guardian Brighton', 'guardian', 'record', 'https://www.theguardian.com/football/brightonfootball/rss', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('chelsea', 'Guardian Chelsea', 'guardian', 'record', 'https://www.theguardian.com/football/chelsea/rss', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('coventry', 'Guardian Coventry City', 'guardian', 'record', 'https://www.theguardian.com/football/coventry/rss', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('crystal_palace', 'Guardian Crystal Palace', 'guardian', 'record', 'https://www.theguardian.com/football/crystalpalace/rss', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('everton', 'Guardian Everton', 'guardian', 'record', 'https://www.theguardian.com/football/everton/rss', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('fulham', 'Guardian Fulham', 'guardian', 'record', 'https://www.theguardian.com/football/fulham/rss', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('hull', 'Guardian Hull City', 'guardian', 'record', 'https://www.theguardian.com/football/hullcity/rss', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('ipswich', 'Guardian Ipswich Town', 'guardian', 'record', 'https://www.theguardian.com/football/ipswichtown/rss', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('leeds', 'Guardian Leeds United', 'guardian', 'record', 'https://www.theguardian.com/football/leedsunited/rss', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('liverpool', 'Guardian Liverpool', 'guardian', 'record', 'https://www.theguardian.com/football/liverpool/rss', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('man_city', 'Guardian Manchester City', 'guardian', 'record', 'https://www.theguardian.com/football/manchestercity/rss', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('man_utd', 'Guardian Manchester United', 'guardian', 'record', 'https://www.theguardian.com/football/manchester-united/rss', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('newcastle', 'Guardian Newcastle United', 'guardian', 'record', 'https://www.theguardian.com/football/newcastleunited/rss', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('nottm_forest', 'Guardian Nottingham Forest', 'guardian', 'record', 'https://www.theguardian.com/football/nottinghamforest/rss', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('spurs', 'Guardian Tottenham Hotspur', 'guardian', 'record', 'https://www.theguardian.com/football/tottenham-hotspur/rss', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('sunderland', 'Guardian Sunderland', 'guardian', 'record', 'https://www.theguardian.com/football/sunderland/rss', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('arsenal', 'BBC Sport Arsenal', 'bbc', 'record', 'https://feeds.bbci.co.uk/sport/football/teams/arsenal/rss.xml', '/sounds/', NULL, '2026-09-09T00:00:00Z'),
  ('brentford', 'BBC Sport Brentford', 'bbc', 'record', 'https://feeds.bbci.co.uk/sport/football/teams/brentford/rss.xml', '/sounds/', NULL, '2026-09-09T00:00:00Z'),
  ('chelsea', 'BBC Sport Chelsea', 'bbc', 'record', 'https://feeds.bbci.co.uk/sport/football/teams/chelsea/rss.xml', '/sounds/', NULL, '2026-09-09T00:00:00Z'),
  ('crystal_palace', 'BBC Sport Crystal Palace', 'bbc', 'record', 'https://feeds.bbci.co.uk/sport/football/teams/crystal-palace/rss.xml', '/sounds/', NULL, '2026-09-09T00:00:00Z'),
  ('fulham', 'BBC Sport Fulham', 'bbc', 'record', 'https://feeds.bbci.co.uk/sport/football/teams/fulham/rss.xml', '/sounds/', NULL, '2026-09-09T00:00:00Z'),
  ('spurs', 'BBC Sport Tottenham Hotspur', 'bbc', 'record', 'https://feeds.bbci.co.uk/sport/football/teams/tottenham-hotspur/rss.xml', '/sounds/', NULL, '2026-09-09T00:00:00Z'),
  ('brighton', 'Brighton official', 'official', 'record', 'https://www.brightonandhovealbion.com/rss', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('crystal_palace', 'Crystal Palace official', 'official', 'record', 'https://www.cpfc.co.uk/rss.xml', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('liverpool', 'Liverpool Echo', 'local', 'colour', 'https://www.liverpoolecho.co.uk/all-about/liverpool-fc/?service=rss', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('everton', 'Liverpool Echo (Everton)', 'local', 'colour', 'https://www.liverpoolecho.co.uk/all-about/everton-fc/?service=rss', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('man_utd', 'Manchester Evening News (United)', 'local', 'colour', 'https://www.manchestereveningnews.co.uk/all-about/manchester-united-fc/?service=rss', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('man_city', 'Manchester Evening News (City)', 'local', 'colour', 'https://www.manchestereveningnews.co.uk/all-about/manchester-city-fc/?service=rss', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('arsenal', 'football.london Arsenal', 'local', 'colour', 'https://www.football.london/arsenal-fc/?service=rss', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('chelsea', 'football.london Chelsea', 'local', 'colour', 'https://www.football.london/chelsea-fc/?service=rss', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('spurs', 'football.london Tottenham', 'local', 'colour', 'https://www.football.london/tottenham-hotspur-fc/?service=rss', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('newcastle', 'Chronicle Live', 'local', 'colour', 'https://www.chroniclelive.co.uk/all-about/newcastle-united-fc/?service=rss', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('aston_villa', 'Birmingham Live', 'local', 'colour', 'https://www.birminghammail.co.uk/all-about/aston-villa-fc/?service=rss', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('leeds', 'Leeds Live', 'local', 'colour', 'https://www.leeds-live.co.uk/all-about/leeds-united-fc/?service=rss', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('hull', 'Hull Live', 'local', 'colour', 'https://www.hulldailymail.co.uk/all-about/hull-city/?service=rss', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('nottm_forest', 'Nottingham Post', 'local', 'colour', 'https://www.nottinghampost.com/all-about/nottingham-forest-fc/?service=rss', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('coventry', 'Coventry Telegraph', 'local', 'colour', 'https://www.coventrytelegraph.net/all-about/coventry-city-fc/?service=rss', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('crystal_palace', 'MyLondon Crystal Palace', 'local', 'colour', 'https://www.mylondon.news/all-about/crystal-palace-fc/?service=rss', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('brighton', 'The Argus (Albion)', 'local', 'colour', 'https://www.theargus.co.uk/sport/albion/rss/', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('ipswich', 'East Anglian Daily Times', 'local', 'colour', 'https://www.eadt.co.uk/sport/ipswich-town/rss/', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('bournemouth', 'Bournemouth Echo', 'local', 'colour', 'https://www.bournemouthecho.co.uk/sport/rss/', NULL, 'Bournemouth', '2026-09-09T00:00:00Z'),
  ('sunderland', 'Sunderland Echo', 'local', 'colour', 'https://www.sunderlandecho.com/sport/football/sunderland-afc/rss', NULL, NULL, '2026-09-09T00:00:00Z'),
  ('leeds', 'Yorkshire Evening Post', 'local', 'colour', 'https://www.yorkshireeveningpost.co.uk/sport/football/leeds-united/rss', NULL, NULL, '2026-09-09T00:00:00Z'),
  (NULL, 'The Athletic football', 'athletic', 'colour', 'https://www.nytimes.com/athletic/rss/football/', NULL, NULL, '2026-09-09T00:00:00Z')
ON CONFLICT (url) DO UPDATE SET
  team_id              = EXCLUDED.team_id,
  name                 = EXCLUDED.name,
  kind                 = EXCLUDED.kind,
  trust                = EXCLUDED.trust,
  reject_link_contains = EXCLUDED.reject_link_contains,
  require_keyword      = EXCLUDED.require_keyword,
  verified_at          = EXCLUDED.verified_at,
  is_active            = true;
