---
name: bug-hunt
description: Hunt GoalDigger for bugs, security holes and fragility before users find them — the iOS app (widget, Live Activity, notification extension, offline, old builds still reading the backend), every anon-callable RPC and table, the Edge Functions, pg_cron, the claude.ai routines, APNs, API-Football, data, cost and secrets. Recon maps every entry point, parallel hunters work from a coverage ledger, a different agent tries to disprove every finding, and the security half runs twice. Use for "bug hunt", "leta buggar", "security audit", "pen test", "before TestFlight", before every TestFlight or App Store build, and after a big delivery.
---

# The bug hunt

Find what is broken, exploitable or fragile, prove it, and hand Anton a ranked list
with a fix and an owner for each. Nothing is fixed until he has decided.

**It is not the council.** `app-council` asks whether each element deserves her
attention (Keep, Iterate, Move, Delete). The bug hunt asks whether it works, whether
it can be abused, and what breaks when something around it fails. The council's
Bugs, Security and Connection seats are a light version of hunters I, A/E and P/O
below. If a hunt ran on the same commit range within 14 days, the council cites
its report instead of re-running those seats.

**Run it:** before every TestFlight or App Store build, after a big delivery, and
when Anton asks. Small change sets get the small size (end of this file).

Method: Cloudflare's open-source security-audit skill, vendored unmodified in
`vendor/cloudflare-security-audit/` (what was kept and why: `VENDORED.md`). This
file adapts it to us. When the two disagree, this file wins. Every item from the
checklists Anton saved is mapped to this system in `CHECKLIST.md`.

## Surfaces

| Hunter | Surface | Starts at |
|---|---|---|
| **A** | Anon surface: the publishable key in the binary, every function, table and view it can reach | `db-health.sh` §7, `SECURITY_PROBE_2026-10-07.md`, migrations 106, 115, 116, 120, 129, 142–144 |
| **E** | Edge Functions: the caller gate (all deploy `--no-verify-jwt`), input, timeouts, error paths | `backend/supabase/functions/*/index.ts`, `_shared/require-service-auth.ts` |
| **P** | Push and Live Activity: tiers, idempotency, dead tokens, priority budget, quiet hours, held ties | `PUSH_RULES.md`, `match-watcher`, `notification-sender`, `matchday-reminder`, `_shared/apns-client.ts`, `_shared/push-tiers.ts` |
| **R** | Routines: RSS and news read by a model that holds Bash and the service key; `post_*.sh` guards; cost | `/Users/anton/goaldigger-routines` (read-only), `DATA_SOURCES.md` "The claude.ai routines" |
| **I** | iOS logic and old builds: 2.2, 2.3 and 2.4 read the same backend; widget, Live Activity, notification extension, App Group, restore, Delete My Data | `ios/GoalDigger/Services`, `Models/AppState.swift`, `LiveActivity/`, `NotificationService/` |
| **D** | Data truth: facts that rot, feeds that lie | `DATA_SOURCES.md`, the `stale-data-audit` skill in report-only mode, `db-health.sh` §8 |
| **O** | Ops, performance, cost: timeouts, retries, retention, migrations, backups, deploy windows, API-Football cap, Anthropic credit | `RUNBOOK.md`, `BACKFILL_RULES.md`, `scripts/io-attribution.sh`, `cron.job` |
| **S** | Supply chain and secrets: the built bundle, git history, pre-commit scan, dependencies, worktrees | `scripts/pre-commit-secret-scan.sh`, `Package.resolved`, Deno imports |
| **U** | User tests in the simulator: the nine beta tests, accessibility, VoiceOver, offline and slow network | `CHECKLIST.md` §B |

## How it runs

```
0 Staging ─► 1 Recon ─► 2 Hunt (A E P R I D O S, parallel) ─► critic ┐
                        3 User tests (U, parallel)                    ├─► 4 Disprove ─► 5 Report ─► Anton decides ─► 6 Fix
                        2b Security hunt again (A E R S, fresh) ──────┘
```

The orchestrator (you) stages, builds the entry-point map, launches agents, keeps
the ledger, verifies and writes the report. Every agent is fresh and knows only
its brief. Working files live in `$H = <scratchpad>/bug-hunt-<YYYY-MM-DD>/`.

## Rules for every agent

- **Read-only on production.** SQL only through `./scripts/sql.sh -c "BEGIN READ ONLY; <query>; ROLLBACK;"`. `sql.sh` itself will run anything, so the wrapper is the rule, not a habit. No deploys, no migrations, no `supabase secrets`, no cron changes, no RemoteTrigger runs, no commits or pushes in this repo or the routines repo.
- **No traffic that does work.** HTTP with the publishable key only as GET to tables and to the four ungated read functions (`quiz-current`, `live-brief-current`, `live-match-current`, `team-season-state`; the fifth ungated one, `delete-my-data`, never). Never call a gated function, not even with a bogus key: if the gate were broken, the call would do the work. Never call an RPC over HTTP (each one writes); check RPC logic from `pg_get_functiondef` and by evaluating its regexes and caps in read-only SQL. Anything that needs a real write to prove becomes `needs_validation` with a rolled-back-transaction plan for Anton.
- **No scanners against Supabase.** No nmap, sqlmap, fuzzers or load tools against `*.supabase.co` (why: `CHECKLIST.md` T1). No load or availability test on anything live.
- **No paid calls.** Never invoke anything in `_shared/claude-client.ts`'s caller graph, `data-fetcher`, `official-squads` or anything that calls API-Football or APNs (CLAUDE.md hard rule). Scratch harnesses that import shipped code run as `deno run --allow-read=<paths>` with no `--allow-net` and no `--allow-env`, so a stray call fails instead of spending.
- **Pushes.** None to real users, ever. If a finding can only be proven with a real push, it goes to Anton as a plan for his own dev devices (`apns_environment = 'development'`, `la-channel-test`).
- **Simulators.** Each agent that needs one creates its own (`xcrun simctl create GD-hunt-<agent> "iPhone 17 Pro"`), builds with its own `-derivedDataPath $H/agents/<agent>/dd`, passes the UDID to every call (never `booted`), and deletes it at the end. Never touch the shared simulator `64CD0EC3-5543-4406-8E68-2F9EEACD0712`. Before trusting a run, `simctl spawn <udid> defaults read com.goaldigger.app` must be empty (memory `project_sim_verification`).
- **Never read** `backend/.env*`, `ios/GoalDigger/Configuration.xcconfig`, `.claude/worktrees/**`. The publishable key for the anon probe comes from the built app, the way an attacker gets it, into a variable that is never printed: `K=$(/usr/libexec/PlistBuddy -c 'Print :SUPABASE_ANON_KEY' "$APP/Info.plist")`.
- **Redact.** No key, token, password, connection string or full APNs token in any output, scratch file or report. Write `sb_publishable_…`, `<cron key>`, the first 8 hex of a token. If a secret appears in output anyway, say so in the report so Anton can rotate it (the 2026-10-04 QA run printed the DB password).
- **No new dependencies, no new tools installed.** Use what is on the machine, the platform (MetricKit, Instruments, Accessibility Inspector, Deno permissions) and the repo.
- **House rules apply to proposed fixes:** no API loops across teams, a push has to earn its place (`PUSH_RULES.md`), never trust one feed for a visible fact (`DATA_SOURCES.md`), every new function needs `REVOKE EXECUTE … FROM PUBLIC, anon, authenticated` checked with `has_function_privilege`.
- **Evidence or it did not happen.** Each candidate gives: fingerprint, surface, severity, file:line (or the SQL and its output), what she or an attacker would see, the repro, how it was checked, the minimal fix, the owner, and CONFIRMED (reproduced on live rows, a real screen or running code) or SUSPECTED (read in code only). Cloudflare's candidate gate applies (`vendor/…/HUNTING.md`, "Core validation rules"): a missing best practice with nobody affected is a hardening note, not a finding.
- End with **"What holds up"**: what was checked and found sound, with the ledger rows. About 1500 words.

## 0. Staging

1. `git status` clean for what is being hunted; record commit, branch and the build number in `$H/README.txt`. Note which builds are in the wild: STATUS.md, plus the commit each build number was set in: `git log --all -S "CURRENT_PROJECT_VERSION = <n>;" -- ios/GoalDigger.xcodeproj/project.pbxproj`.
2. Build once (CLAUDE.md command, `-derivedDataPath $H/dd`); agents copy the `.app`.
3. Run the existing checks and save their output: `./scripts/db-health.sh`, `verify-push-rules.sh`, `verify-push-eligible.sh`, `verify-tracking-plan.sh`, `verify-cron-auth.sh`, `verify-arch-map.sh`, `deno test -A backend/supabase/functions/`. A red check here is a finding already; the hunt starts from it.
4. Read the last reports so nothing fixed is re-reported unless it regressed: the newest `docs/bug-hunt/`, `docs/council/` seats, `AUDIT_FINDINGS.md` open items, `CHANGELOG_SECURITY.md` "Open", the newest `QA_*` and `BUG_AUDIT_*`.

## 1. Reconnaissance: the entry-point map

Two research agents, read-only, using `vendor/…/RECONNAISSANCE.md` prompts 1b and 1c
adapted to the surfaces above, plus your own catalog queries. The output is the
coverage ledger, `$H/entry-points.csv`, one row per entry point per hunter:

`id, hunter, surface, entry, where, principal, boundary, checklist_rows, status, agent, checks, fingerprints, unresolved`

Enumerate from the system, never from memory:
- **anon reach:** every `public` function with `has_function_privilege('anon', oid, 'EXECUTE')`, every table and view with any anon privilege, exposed schemas, the four app RPCs and `delete_app_events`.
- **Edge Functions:** every directory in `backend/supabase/functions/` and every deployed one (`supabase functions list --project-ref cwgpsmbunrocrofziqad`); gate present or not; what it calls out to.
- **Schedules:** `cron.job` (command, schedule, active), routines' "Schedules, in one place" in their README.
- **App inputs:** every `APIClient` call and the table or function behind it, push payload keys and `content_id` prefixes the app routes on (`AppDelegate`), Live Activity content-state, the notification extension's request, App Group keys, the Facebook URL scheme, launch arguments (DEBUG-only? check `#if DEBUG`), bundled JSON refreshed from `my_turn_content`.
- **External feeds:** API-Football endpoints in use, RSS sources (`team_news_sources`), premierleague.com.
- **Every `CHECKLIST.md` row marked `gap` or `covered`** becomes at least one ledger row.

Status values: `planned`, `in_progress`, `covered`, `candidate`, `blocked`, `n.a.`, `deferred` (with the reason). **Coverage gate:** before the report, no row is `planned` or `in_progress`, and every `deferred` row is listed in the report.

## 2. The hunt

Launch the hunters in parallel, each with: these rules, the commit, `ARCHITECTURE.md`
and `STATUS.md` to read first, its ledger rows, its `CHECKLIST.md` rows, and the
vendored files named below to read by path (`vendor/cloudflare-security-audit/…`).
Every hunter uses the core hunting method in `HUNTING.md` and the relevant classes
in `ATTACK-CLASSES.md`. Each returns its candidates, its ledger rows updated, its
hardening notes and **"What holds up"**.

**Feed real strings through shipped code.** Export live rows with read-only SQL to
`$H/agents/<agent>/rows/` and run them through the shipped functions in a scratch
harness. Hand-picked fixtures are how the 2026-09-09 defects passed the suites.

- **A, anon surface.** Reads `DATA-ISOLATION-AND-LIFECYCLE.md`, `WEB-PROTOCOL-AND-AUTH.md` (API-key classes). Catalog checks with `has_function_privilege` and `has_table_privilege` (not `information_schema`, which hides `MAINTAIN`), `pg_policy` with roles, views that read RLS tables, SECURITY DEFINER functions and their `search_path`. The GET probe from `SECURITY_PROBE_2026-10-07.md` "Reproduce" over every table, `Accept-Profile` for `net`, `cron`, `vault`, `storage`, and the ungated read functions with malformed parameters. Replaces the PentAGI-style scan (`CHECKLIST.md` T1).
- **E, Edge Functions.** Reads `CLOUD-AND-DEPLOYMENT.md`, `PROTOCOLS-RPC-AND-MESSAGING.md`, `RESOURCE-EXHAUSTION-AND-AVAILABILITY.md`. For every function: is the gate the first thing on every method, what does it trust from the body, does every outbound `fetch` have a timeout, what does a thrown error leave half-written, does it read more rows than 1,000 without paging. `deno check` on each.
- **P, push and Live Activity.** Reads `PROTOCOLS-RPC-AND-MESSAGING.md` (duplicate delivery, ordering). `PUSH_RULES.md` §1 against `_shared/push-tiers.ts` with the last 30 days of fixtures; duplicate `apns_send` per target and device; quiet hours across the clock change; priority-10 sends per match against the budget; held ties and shootouts; `isTokenDead`; a device following both sides of a derby; what each old build does with today's payloads (with I).
- **R, routines.** Reads `AI-AND-LLM.md`, `SUPPLY-CHAIN-AND-RELEASE.md`. Per routine: inputs, tools, credential and its reach, outputs, and the deterministic guard between model and database. Craft a malicious RSS item as a local fixture and push it through `parse_club_rss.py`, `fact_checks.py` and each `post_*.sh` guard with posting stubbed, never against Supabase. Confirm no script loops a paid call, and that `REBUILD.md` rebuilds every routine the closing account runs.
- **I, iOS logic and old builds.** Reads `DESKTOP-MOBILE-AND-LOCAL-IPC.md`. Push-tap routing, App Group data shared with the extension and widget, token refresh after restore, Delete My Data completeness (server rows, Live Activities, calendar, App Group, Meta ids), decode tolerance. **Contract:** decode live `team_pages.content`, `live-match-current`, `live-brief-current` and a stored Live Activity content-state with each in-the-wild build's model types (`git show <build-commit>:<file>` compiled in a scratch Swift package or read side by side). An update an old build cannot decode is dropped without a sound.
- **D, data truth.** Runs the `stale-data-audit` skill in report-only mode, every section, nothing fixed; then every visible fact resting on a field `DATA_SOURCES.md` marks not trusted, and any two surfaces that disagree about one match.
- **O, ops, performance, cost.** `CHECKLIST.md` rows marked O. Retention per table with weekly growth, migration files against the live catalog, backoff, alerting, deploy windows against `poll_leagues()`, `io-attribution.sh`, `pg_stat_statements` top 20, API-Football calls per day against 7,500, every `callClaude()` caller and its trigger. Backups and restore are questions for Anton (`needs_validation` with the exact dashboard place to look).
- **S, supply chain and secrets.** Reads `SUPPLY-CHAIN-AND-RELEASE.md`; runs `ATTACK-CLASSES.md` "Obvious things" literally. `strings` on the built `.app` and its frameworks, `git log -p --since=60.days` in both repos for key shapes the pre-commit scan misses, `.gitignore` coverage, `git worktree list` (never open a worktree), dependency advisories for the pinned versions, debug-only files shipped in Release (NEW-21).

**Coverage critic.** When the wave returns, one fresh agent gets the ledger and the
recon notes, never the candidates' write-ups, and returns unmapped entry points,
rows closed without checks, and one **Wildcard** pass (`ATTACK-CLASSES.md`). Assign
what it finds to a second, smaller wave or mark it `deferred` with the reason.

**2b. The security hunt runs twice.** Cloudflare's own runs found about half of the
total in one pass. After the first wave, launch fresh A, E, R and S agents with the
first run's ledger and a list of candidate fingerprints and titles only (not their
reasoning), told to work the rows that were thinnest, the `blocked` and `deferred`
ones, and the entry points the critic added. They must not re-report a fingerprint
already listed (Cloudflare's prior-run rules, `SKILL.md` "Coverage and prior runs").
Merge by fingerprint.

## 3. User tests

One or two U agents, each with its own simulator set to `Europe/London`. Run the
rows in `CHECKLIST.md` §B. simctl cannot tap; use the iOS Simulator control tool
(`tap`, `text`, `swipe`) on the agent's own device, which asks Anton for device
access on first use. What still cannot be driven (offline, slow network, a real
push, the notification extension, the Lock Screen widget) becomes a short
checklist for Anton's phone in the report, never a guess.

- The nine tests, each on the GoalDigger flow named in §B, with fake names and a fresh install.
- Dynamic Type at AccessibilityXL (exact constant in memory `project_sim_verification`), light and dark, the smallest supported screen.
- VoiceOver spot check on onboarding, a feed card, Matchday After and Settings.
- Record each result as `test | flow | expected | seen | screenshot path`, and every failure as a candidate.

## 4. Disprove

Every candidate goes to a fresh verifier that did not find it, using the verifier
prompt in `vendor/…/VALIDATION-AND-REPORTING.md` ("You did not write this
candidate. Try to refute it"), under the same rules. It returns `confirmed`,
`needs_validation` (with the exact unresolved fact and who can observe it) or
`rejected` (with the reason). One verifier per HIGH or MEDIUM candidate; LOW
candidates may share one verifier per hunter.

Then **verify every CONFIRMED HIGH yourself** before it counts. Seats and hunters
have been wrong (2026-09-09: two confirmed findings did not hold). What you cannot
reproduce drops to `needs_validation`.

**Severity.** Security findings use Cloudflare's anchors (`vendor/…/SKILL.md`,
"Separate priority from certainty"). For everything else:
- **HIGH**: a wrong fact or a wrong push reaches many users, data is lost, a crash on launch or on a common path, a push to people who should not get it, or money spent without a cap.
- **MEDIUM**: a flow broken for a subset (a build, a tier, a state), or silent loss of something she saved.
- **LOW**: cosmetic, rare, or self-correcting.
In the report, HIGH covers Cloudflare's critical and high, LOW covers low and informational. Only `confirmed` gets a severity.

## 5. Report

1. `$H/findings.json`, every confirmed, needs-validation and rejected record in the
   vendored schema, sorted by fingerprint, then
   `node .claude/skills/bug-hunt/vendor/cloudflare-security-audit/validate-findings.cjs $H/findings.json`
   until it prints PASS. Fingerprints look like `edge/notification-sender/apns-fetch-no-timeout`.
   `file` is repository-relative; routines files are written `routines/<file>`
   (meaning `/Users/anton/goaldigger-routines/<file>`), and a database object
   with no migration is `db/<schema>.<object>` at line 1. For a user-facing bug,
   `attacker_perspective` names who meets it ("her, on build 2.2, offline").
2. `docs/bug-hunt/BUG_HUNT_<YYYY-MM-DD>.md`:
   - Header: commit, builds in the wild, date, hunt size, agents spent, what could not be staged (and Anton's phone checklist for it).
   - **Decisions for Anton** first: each HIGH and MEDIUM in one line, with fix, owner and cost.
   - Findings table, HIGH to LOW: id, title, surface, severity, CONFIRMED or SUSPECTED, owner (**app build** / **server** / **routine** / **Anton**), fix in one sentence.
   - Each finding: evidence, repro, fix proposal.
   - Needs validation: the exact fact and who can observe it.
   - Hardening notes, kept apart from findings.
   - Coverage: ledger counts by status, deferred rows with reasons, what the critic added, what the second security run found that the first did not.
   - `CHECKLIST.md` rows whose status changed.
   - **What holds up.**
3. Copy `findings.json` to `docs/bug-hunt/BUG_HUNT_<YYYY-MM-DD>.json`. Grep both files for key shapes (`eyJ`, `sb_secret_`, `sb_publishable_`, `sk-ant-`, `postgres://`, `BEGIN PRIVATE`) before committing; the commit uses named paths only.
4. Send Anton the decisions list in a few sentences, in his language.

## 6. Fix, only after Anton decides

Fixers build only what Anton accepted. One worktree per fix: agent worktrees are cut
from the main base branch, so either cut it yourself
(`git worktree add <path> -b fix/<slug> claude/feature-planning-1q4m3p`) or reset
the agent's worktree onto the feature branch tip first. Own simulator and
derived data, one commit each, no push, no deploy. Integrate as a reviewed
proposal: read the agent's own commit with `git show <sha>`, cherry-pick or
re-apply by hand, never merge blind (memory `feedback_bg_agent_worktree_base`).
Deploys and migrations stay with you, serialized, after review (memory
`feedback_run_migrations_yourself`). Remove each worktree when its fix lands: it
holds a copy of `backend/.env` (CLAUDE.md). Each fix leaves one runnable check
behind, and the finding's `CHECKLIST.md` row moves to `covered` in the same commit.

## Size

| Size | When | Agents |
|---|---|---|
| **Small** | A point release, a backend-only change, a re-hunt of fixes | Recon by you; hunters for the touched surfaces only (often E + P, or I + U); no second run; verifiers for HIGH and MEDIUM. About 4–5. |
| **Medium** (default) | Before a TestFlight build, after a big delivery | 2 recon, 8 hunters (A E P R I D O S), 1 U, 1 critic, then 4 for the second security run and the verifiers. **At most 10 running at once**; launch in waves. |
| **Large** | Before an App Store submission, after a security change, or when the last medium found a HIGH | Split hunters per subsystem (match-watcher alone; each routine family; iOS by module), a critic after every wave until one comes back clean, two U agents (match week and worst week), and a fresh second verifier for every HIGH. 15–20 in waves of 10. |

Scale by adding hunters per subsystem, never by giving one hunter more surfaces.
Shrinking drops surfaces, never the disprove step, the evidence standard or the
read-only rules.

Recount `CHECKLIST.md` after editing it:
`grep -oE '^\| [A-Z][A-Za-z0-9-]* \| [^|]+ \| (covered|gap|n\.a\.) \|' .claude/skills/bug-hunt/CHECKLIST.md | grep -oE '(covered|gap|n\.a\.) \|$' | sort | uniq -c`
