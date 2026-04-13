-- 004_seed_all_pl_teams.sql
-- Goal Digger — Seed all 20 Premier League 2025/26 teams
-- API-Football team IDs verified at https://www.api-football.com/documentation-v3

-- ============================================================
-- TEAMS TABLE — all 20 PL clubs
-- ============================================================

INSERT INTO teams (id, display_name, api_football_id, short_name) VALUES
    ('arsenal',        'Arsenal',                  42,  'Arsenal'),
    ('aston_villa',    'Aston Villa',              66,  'Aston Villa'),
    ('bournemouth',    'AFC Bournemouth',          35,  'Bournemouth'),
    ('brentford',      'Brentford',                55,  'Brentford'),
    ('brighton',       'Brighton & Hove Albion',   51,  'Brighton'),
    ('chelsea',        'Chelsea',                  49,  'Chelsea'),
    ('crystal_palace', 'Crystal Palace',           52,  'Crystal Palace'),
    ('everton',        'Everton',                  45,  'Everton'),
    ('fulham',         'Fulham',                   36,  'Fulham'),
    ('ipswich',        'Ipswich Town',             57,  'Ipswich'),
    ('leicester',      'Leicester City',           46,  'Leicester'),
    ('liverpool',      'Liverpool',                40,  'Liverpool'),
    ('man_city',       'Manchester City',          50,  'Man City'),
    ('man_utd',        'Manchester United',        33,  'Man Utd'),
    ('newcastle',      'Newcastle United',         34,  'Newcastle'),
    ('nottm_forest',   'Nottingham Forest',        65,  'Nott''m Forest'),
    ('southampton',    'Southampton',              41,  'Southampton'),
    ('spurs',          'Tottenham Hotspur',        47,  'Spurs'),
    ('west_ham',       'West Ham United',          48,  'West Ham'),
    ('wolves',         'Wolverhampton Wanderers',  39,  'Wolves')
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- TEAM CONTEXT — empty flags for all teams
-- ============================================================

INSERT INTO team_context (team_id, flags) VALUES
    ('arsenal',        '[]'),
    ('aston_villa',    '[]'),
    ('bournemouth',    '[]'),
    ('brentford',      '[]'),
    ('brighton',       '[]'),
    ('chelsea',        '[]'),
    ('crystal_palace', '[]'),
    ('everton',        '[]'),
    ('fulham',         '[]'),
    ('ipswich',        '[]'),
    ('leicester',      '[]'),
    ('liverpool',      '[]'),
    ('man_city',       '[]'),
    ('man_utd',        '[]'),
    ('newcastle',      '[]'),
    ('nottm_forest',   '[]'),
    ('southampton',    '[]'),
    ('spurs',          '[]'),
    ('west_ham',       '[]'),
    ('wolves',         '[]')
ON CONFLICT (team_id) DO NOTHING;

-- ============================================================
-- TEAM PAGES — seed static cards (basics + rivalry) for all 20
-- Dynamic cards (form, season, ones_to_know, next_fixture)
-- populated later by team-page-generator edge function.
-- ============================================================

INSERT INTO team_pages (team_id, content) VALUES
('arsenal', '{
  "schema_version": 1,
  "cards": {
    "basics": {
      "updated_at": "2026-04-07T00:00:00Z",
      "nickname": "The Gunners",
      "stadium": "Emirates Stadium, London",
      "fun_fact": "Arsenal once went an entire 49-game Premier League season unbeaten. They literally called themselves The Invincibles. [his name] has probably mentioned this at least twice."
    },
    "rivalry": {
      "updated_at": "2026-04-07T00:00:00Z",
      "text": "Tottenham Hotspur — the North London Derby. Arsenal and Spurs are neighbours and have been winding each other up since 1887. If [his name] supports Arsenal, he does NOT like Spurs. This is non-negotiable."
    }
  }
}'),
('aston_villa', '{
  "schema_version": 1,
  "cards": {
    "basics": {
      "updated_at": "2026-04-07T00:00:00Z",
      "nickname": "The Villans",
      "stadium": "Villa Park, Birmingham",
      "fun_fact": "Aston Villa were one of the founding members of the Football League back in 1888. They also won the European Cup in 1982, which [his name] will definitely bring up if anyone questions their credentials."
    },
    "rivalry": {
      "updated_at": "2026-04-07T00:00:00Z",
      "text": "Birmingham City — the Second City Derby. Villa and Birmingham City have been at it for over a century. Villa fans see themselves as the bigger club. If [his name] ever mentions ''the Blues'' with contempt, he means Birmingham, not Chelsea."
    }
  }
}'),
('bournemouth', '{
  "schema_version": 1,
  "cards": {
    "basics": {
      "updated_at": "2026-04-07T00:00:00Z",
      "nickname": "The Cherries",
      "stadium": "Vitality Stadium, Bournemouth",
      "fun_fact": "Bournemouth were nearly kicked out of the Football League in 2008 when they went into administration. Now they are in the Premier League. Proper underdog story."
    },
    "rivalry": {
      "updated_at": "2026-04-07T00:00:00Z",
      "text": "Southampton — the South Coast Derby. Both clubs are from the south coast and do not like each other. Southampton fans think they are the bigger club. Bournemouth fans think they are the better one right now."
    }
  }
}'),
('brentford', '{
  "schema_version": 1,
  "cards": {
    "basics": {
      "updated_at": "2026-04-07T00:00:00Z",
      "nickname": "The Bees",
      "stadium": "Gtech Community Stadium, London",
      "fun_fact": "Brentford use data analytics more than almost any other club. They are basically the Moneyball of English football. [his name] probably respects this if he is into stats."
    },
    "rivalry": {
      "updated_at": "2026-04-07T00:00:00Z",
      "text": "Fulham — the West London rivalry. They are practically neighbours in West London. Not the most intense rivalry in football, but [his name] will still want them to lose."
    }
  }
}'),
('brighton', '{
  "schema_version": 1,
  "cards": {
    "basics": {
      "updated_at": "2026-04-07T00:00:00Z",
      "nickname": "The Seagulls",
      "stadium": "American Express Stadium, Brighton",
      "fun_fact": "Brighton nearly dropped out of professional football entirely in the late 1990s. Now they play in this gorgeous stadium by the sea and keep selling players for ridiculous money."
    },
    "rivalry": {
      "updated_at": "2026-04-07T00:00:00Z",
      "text": "Crystal Palace — the M23 Derby (named after the motorway between them). This is a proper heated one. Brighton and Palace fans genuinely do not get along. If [his name] supports Brighton, do not compliment anything about Crystal Palace."
    }
  }
}'),
('chelsea', '{
  "schema_version": 1,
  "cards": {
    "basics": {
      "updated_at": "2026-04-07T00:00:00Z",
      "nickname": "The Blues",
      "stadium": "Stamford Bridge, London",
      "fun_fact": "Chelsea have had more managers since 2000 than most clubs have had since they were founded. The owner changes managers like most people change their phone case."
    },
    "rivalry": {
      "updated_at": "2026-04-07T00:00:00Z",
      "text": "Tottenham and Arsenal — Chelsea fans enjoy winding up both. But the real personal one is Tottenham. If [his name] supports Chelsea, he will have opinions about Spurs."
    }
  }
}'),
('crystal_palace', '{
  "schema_version": 1,
  "cards": {
    "basics": {
      "updated_at": "2026-04-07T00:00:00Z",
      "nickname": "The Eagles",
      "stadium": "Selhurst Park, London",
      "fun_fact": "Crystal Palace are named after the original Crystal Palace that was built for the Great Exhibition in 1851. The atmosphere at Selhurst Park is genuinely one of the best in the league."
    },
    "rivalry": {
      "updated_at": "2026-04-07T00:00:00Z",
      "text": "Brighton — the M23 Derby. Palace and Brighton have a deep, genuine dislike for each other. This is one of the most intense rivalries in English football outside the top six."
    }
  }
}'),
('everton', '{
  "schema_version": 1,
  "cards": {
    "basics": {
      "updated_at": "2026-04-07T00:00:00Z",
      "nickname": "The Toffees",
      "stadium": "Goodison Park, Liverpool",
      "fun_fact": "Everton are one of the founding members of the Football League and have spent more seasons in the top flight than any other club. They just have not won a trophy since 1995, which is a sore point."
    },
    "rivalry": {
      "updated_at": "2026-04-07T00:00:00Z",
      "text": "Liverpool — the Merseyside Derby. They share a city and the rivalry runs deep. Unlike most derbies, families in Liverpool are often split between the two clubs. If [his name] supports Everton, Liverpool''s success is physically painful for him."
    }
  }
}'),
('fulham', '{
  "schema_version": 1,
  "cards": {
    "basics": {
      "updated_at": "2026-04-07T00:00:00Z",
      "nickname": "The Cottagers",
      "stadium": "Craven Cottage, London",
      "fun_fact": "Craven Cottage sits right on the Thames and is one of the prettiest football grounds in England. It has a proper old-school charm that most modern stadiums lack."
    },
    "rivalry": {
      "updated_at": "2026-04-07T00:00:00Z",
      "text": "Chelsea and Brentford — Fulham are sandwiched between two West London rivals. Chelsea is the bigger rivalry historically, but Brentford has become more relevant since both clubs are now in the Premier League."
    }
  }
}'),
('ipswich', '{
  "schema_version": 1,
  "cards": {
    "basics": {
      "updated_at": "2026-04-07T00:00:00Z",
      "nickname": "The Tractor Boys",
      "stadium": "Portman Road, Ipswich",
      "fun_fact": "Ipswich won back-to-back promotions to reach the Premier League. They went from League One to the top flight in two seasons, which is genuinely remarkable."
    },
    "rivalry": {
      "updated_at": "2026-04-07T00:00:00Z",
      "text": "Norwich City — the East Anglian Derby. This is one of the most passionate rivalries in English football outside the top six. Ipswich and Norwich fans live for this fixture. If [his name] supports Ipswich, Norwich is a four-letter word."
    }
  }
}'),
('leicester', '{
  "schema_version": 1,
  "cards": {
    "basics": {
      "updated_at": "2026-04-07T00:00:00Z",
      "nickname": "The Foxes",
      "stadium": "King Power Stadium, Leicester",
      "fun_fact": "Leicester won the Premier League in 2016 at 5000-to-1 odds. It is genuinely considered the greatest sporting upset of all time. [his name] will never let anyone forget this."
    },
    "rivalry": {
      "updated_at": "2026-04-07T00:00:00Z",
      "text": "Nottingham Forest — the East Midlands Derby. Leicester and Forest are close neighbours and the rivalry is fierce. There is also a strong dislike of Derby County, but they are not in the Premier League."
    }
  }
}'),
('liverpool', '{
  "schema_version": 1,
  "cards": {
    "basics": {
      "updated_at": "2026-04-07T00:00:00Z",
      "nickname": "The Reds",
      "stadium": "Anfield, Liverpool",
      "fun_fact": "Before every home game, the entire stadium sings You''ll Never Walk Alone. It is one of the most iconic moments in world football. If [his name] gets emotional about it, that is completely normal."
    },
    "rivalry": {
      "updated_at": "2026-04-07T00:00:00Z",
      "text": "Manchester United — this is THE rivalry in English football. Liverpool and United have been competing for everything since the 1960s. If [his name] supports Liverpool, the words ''Man United'' will trigger a reaction. Every time."
    }
  }
}'),
('man_city', '{
  "schema_version": 1,
  "cards": {
    "basics": {
      "updated_at": "2026-04-07T00:00:00Z",
      "nickname": "The Citizens",
      "stadium": "Etihad Stadium, Manchester",
      "fun_fact": "Man City were in the third tier of English football in 1999. They have since won the Premier League multiple times and the Champions League. Money helps, but the transformation is genuinely unprecedented."
    },
    "rivalry": {
      "updated_at": "2026-04-07T00:00:00Z",
      "text": "Manchester United — the Manchester Derby. They share a city and the rivalry is intense. City fans spent decades living in United''s shadow, so the recent success feels especially sweet to [his name]."
    }
  }
}'),
('man_utd', '{
  "schema_version": 1,
  "cards": {
    "basics": {
      "updated_at": "2026-04-07T00:00:00Z",
      "nickname": "The Red Devils",
      "stadium": "Old Trafford, Manchester",
      "fun_fact": "Old Trafford is called the Theatre of Dreams. It is the biggest club stadium in England. [his name] has probably been or desperately wants to go."
    },
    "rivalry": {
      "updated_at": "2026-04-07T00:00:00Z",
      "text": "Liverpool and Manchester City — United have two massive rivalries. Liverpool is the historic one, going back decades. City is the local one, made more painful by City''s recent dominance. If [his name] seems grumpy, one of these two probably won."
    }
  }
}'),
('newcastle', '{
  "schema_version": 1,
  "cards": {
    "basics": {
      "updated_at": "2026-04-07T00:00:00Z",
      "nickname": "The Magpies",
      "stadium": "St James'' Park, Newcastle",
      "fun_fact": "St James'' Park is right in the middle of Newcastle city centre. On match days the entire city basically shuts down and revolves around the football. The fans are famously passionate, even wearing short sleeves in December."
    },
    "rivalry": {
      "updated_at": "2026-04-07T00:00:00Z",
      "text": "Sunderland — the Tyne-Wear Derby. This is one of the most intense rivalries in England. Sunderland are not in the Premier League right now, but that does not stop [his name] from having strong feelings about them."
    }
  }
}'),
('nottm_forest', '{
  "schema_version": 1,
  "cards": {
    "basics": {
      "updated_at": "2026-04-07T00:00:00Z",
      "nickname": "The Tricky Trees",
      "stadium": "The City Ground, Nottingham",
      "fun_fact": "Nottingham Forest won the European Cup twice in 1979 and 1980 under Brian Clough. They had been in the second division just a few years before. It is one of the most remarkable stories in football history."
    },
    "rivalry": {
      "updated_at": "2026-04-07T00:00:00Z",
      "text": "Leicester City and Derby County — the East Midlands trio all dislike each other. Leicester is the current Premier League rival. Derby is the deeper historic hatred but they are in a lower division."
    }
  }
}'),
('southampton', '{
  "schema_version": 1,
  "cards": {
    "basics": {
      "updated_at": "2026-04-07T00:00:00Z",
      "nickname": "The Saints",
      "stadium": "St Mary''s Stadium, Southampton",
      "fun_fact": "Southampton''s academy is legendary. Alan Shearer, Matt Le Tissier, Gareth Bale, and Luke Shaw all started there. They develop talent better than almost anyone."
    },
    "rivalry": {
      "updated_at": "2026-04-07T00:00:00Z",
      "text": "Portsmouth — the South Coast Derby. This is a fierce, proper old-school rivalry. Portsmouth are in a lower division now, but [his name] still does not like them. At all."
    }
  }
}'),
('spurs', '{
  "schema_version": 1,
  "cards": {
    "basics": {
      "updated_at": "2026-04-07T00:00:00Z",
      "nickname": "Spurs (or Lilywhites)",
      "stadium": "Tottenham Hotspur Stadium, London",
      "fun_fact": "Spurs built one of the most expensive stadiums in the world. It has a retractable pitch and its own microbrewery. The stadium is incredible. The trophy cabinet is... a work in progress."
    },
    "rivalry": {
      "updated_at": "2026-04-07T00:00:00Z",
      "text": "Arsenal — the North London Derby. This is a deep, personal, generational rivalry. If [his name] supports Spurs, Arsenal winning anything causes genuine distress. This is not an exaggeration."
    }
  }
}'),
('west_ham', '{
  "schema_version": 1,
  "cards": {
    "basics": {
      "updated_at": "2026-04-07T00:00:00Z",
      "nickname": "The Hammers",
      "stadium": "London Stadium, London",
      "fun_fact": "West Ham moved from their beloved Boleyn Ground to the London Stadium (the Olympic stadium) in 2016. [his name] probably still has feelings about this. Most West Ham fans do."
    },
    "rivalry": {
      "updated_at": "2026-04-07T00:00:00Z",
      "text": "Millwall and Tottenham — West Ham''s biggest historical rivalry is Millwall (a lower league club), but in the Premier League the main one is Spurs. If [his name] seems unusually tense before a Spurs game, now you know why."
    }
  }
}'),
('wolves', '{
  "schema_version": 1,
  "cards": {
    "basics": {
      "updated_at": "2026-04-07T00:00:00Z",
      "nickname": "Wolves",
      "stadium": "Molineux Stadium, Wolverhampton",
      "fun_fact": "Wolves were one of the biggest clubs in England in the 1950s and actually played in some of the first-ever floodlit European matches. They have a strong Portuguese connection these days thanks to their links with super-agent Jorge Mendes."
    },
    "rivalry": {
      "updated_at": "2026-04-07T00:00:00Z",
      "text": "West Bromwich Albion — the Black Country Derby. West Brom are not in the Premier League at the moment, but this is a deeply personal rivalry. Aston Villa is also a strong dislike. If [his name] supports Wolves, the whole West Midlands is enemy territory."
    }
  }
}')
ON CONFLICT (team_id) DO NOTHING;

-- ============================================================
-- CRON JOB — Weekly team page refresh (Monday 08:00 UTC)
-- ============================================================

SELECT cron.schedule(
    'team-page-refresh',
    '0 8 * * 1',
    $$SELECT net.http_post(
        url := current_setting('app.settings.supabase_url') || '/functions/v1/team-page-generator',
        body := '{"mode": "full"}'::jsonb,
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
        )
    )$$
);

-- ============================================================
-- ON-SELECT TRIGGER: Generate team page for newly registered teams
-- When a device token is inserted for a team whose team_pages row
-- has no dynamic cards (form), trigger a full generation in the background.
-- Uses pg_net (Supabase HTTP extension) — fire-and-forget, never blocks.
-- ============================================================

CREATE OR REPLACE FUNCTION trigger_team_page_for_new_device()
RETURNS TRIGGER AS $$
DECLARE
    has_dynamic boolean;
BEGIN
    -- Check if this team's page already has dynamic content (form card)
    SELECT (content->'cards'->'form') IS NOT NULL
    INTO has_dynamic
    FROM team_pages
    WHERE team_id = NEW.team_id;

    -- If no dynamic content exists, trigger a full generation
    IF NOT has_dynamic OR has_dynamic IS NULL THEN
        PERFORM net.http_post(
            url := current_setting('app.settings.supabase_url') || '/functions/v1/team-page-generator',
            body := jsonb_build_object('mode', 'full', 'team_id', NEW.team_id),
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
            )
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_device_token_insert
    AFTER INSERT ON device_tokens
    FOR EACH ROW
    EXECUTE FUNCTION trigger_team_page_for_new_device();
