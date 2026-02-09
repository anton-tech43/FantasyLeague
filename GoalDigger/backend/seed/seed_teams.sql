-- Goal Digger — Seed Data: Teams
-- API-Football team IDs: Arsenal = 42, Man Utd = 33, West Ham = 48
-- Verify with: GET /v3/teams?league=39&season=2025

INSERT INTO teams (id, display_name, api_football_id, short_name) VALUES
    ('arsenal',  'Arsenal',           42,  'Arsenal'),
    ('man_utd',  'Manchester United',  33,  'Man Utd'),
    ('west_ham', 'West Ham United',    48,  'West Ham')
ON CONFLICT (id) DO NOTHING;
