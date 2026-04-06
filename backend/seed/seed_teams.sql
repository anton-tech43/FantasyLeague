-- seed_teams.sql
-- Goal Digger — Initial team data for v1 (3 Premier League teams)
-- API-Football team IDs: Arsenal=42, Manchester United=33, West Ham=48

INSERT INTO teams (id, display_name, api_football_id, short_name) VALUES
    ('arsenal',  'Arsenal',           42,  'Arsenal'),
    ('man_utd',  'Manchester United',  33,  'Man Utd'),
    ('west_ham', 'West Ham United',    48,  'West Ham');

-- Initialize team_context with empty flags
INSERT INTO team_context (team_id, flags) VALUES
    ('arsenal',  '[]'),
    ('man_utd',  '[]'),
    ('west_ham', '[]');
