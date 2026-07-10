# Claude-session notes for GoalDigger

This file is auto-loaded at the start of every Claude Code session in this repo. Keep it short and operational — the long-form docs live elsewhere (see README).

---

## ⛔ Hard rule: never loop a paid Anthropic API call across teams

**Default for any cross-team data fix is direct SQL or a one-off claude.ai routine — NOT a script that loops `team-page-generator` (or any other Edge Function in `_shared/claude-client.ts`'s caller graph).**

Reason: Edge Functions calling `callClaude()` bill the Anthropic API CREDIT BALANCE (pay-per-token). Routines bill the claude.ai SUBSCRIPTION QUOTA (flat monthly fee). The wallet hits differently.

On 2026-05-20, a 50-team basics backfill via `team-page-generator` burned ~$4-5 and bottomed the API balance. The same work via direct SQL (because the data was already in `raw_fetch_logs`) would have cost $0. Don't repeat this.

**Before firing ANY cross-team backfill, read `/BACKFILL_RULES.md`.** It contains:
- The decision tree (SQL → routine → Edge Function)
- The list of API-credit-burning functions
- The list of free routines you can copy
- A cost-estimation formula
- The IDLE_TIMEOUT failure pattern that means "API balance depleted, not function broken"

If you're the AI assistant reading this: when a user asks for a "backfill" or "regenerate for all teams" or anything that smells like a loop over teams, **explicitly ask whether SQL or a routine can do it before reaching for a curl loop**. Even when the user asks for speed, $0 SQL is faster than waiting on 50 LLM calls.

---

## How to write code here (lazy-senior-dev default)

The best code is the code never written. Lazy means efficient, not careless. Before adding code, stop at the first rung that holds:

1. Does this need to exist at all? (YAGNI) → if not, skip it.
2. Does the standard library / language built-in do it? Use it.
3. Does a native platform feature cover it? Use it.
4. Does an already-installed dependency solve it? Use it. (No new deps without a reason.)
5. Can it be one line? Make it one line.
6. Only then: the minimum code that works.

Defaults: no unrequested abstractions, deletion over addition, boring over clever, fewest files. Answer/code first, then at most a few lines on what was skipped and when to add it — if the explanation is longer than the code, cut it (explanation the user asked for is exempt).

**Never lazy about** (these are not on the chopping block): trust-boundary/input validation, error handling that prevents data loss, security, accessibility, and anything the user said to keep. Non-trivial logic leaves ONE runnable check behind (a small test or assert-based self-check); trivial one-liners don't need one. Mark intentional shortcuts with a `// ponytail:` comment naming the ceiling + upgrade path.

(Adapted from the ponytail ruleset — reviewed safe, folded in here instead of installing the plugin so there's nothing always-on to trust.)

---

## Other operational notes

- **⭐ How the app ACTUALLY works**: read `ARCHITECTURE.md` FIRST — it's the authoritative,
  current (V2.2, mid-WC-2026) source of truth and supersedes `PRD.md` / `AGENT_CONTRACTS.md`
  / `PROMPTS.md` (those are stale V1). Known bugs/security/staleness: `AUDIT_FINDINGS.md`.
  Two things every doc except those gets wrong: (1) live content is produced by **claude.ai
  routines**, not the dormant Edge `content-generator`; (2) the app is **20 PL clubs + 48 WC
  countries** (not "3 teams") and users can now follow up to 2 of each (arrays model).
- **iOS sim**: `xcodebuild -project ios/GoalDigger.xcodeproj -scheme GoalDigger -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
- **Edge Function deploy**: from `backend/` dir, `supabase functions deploy <name> --project-ref cwgpsmbunrocrofziqad --no-verify-jwt`
- **DB access**: `set -a && source backend/.env && set +a && /opt/homebrew/opt/libpq/bin/psql "$SUPABASE_DB_URL"`
- **JSONB null trap**: `WHERE x IS NULL` does NOT match a JSONB literal `null`. Use `WHERE x IS NULL OR jsonb_typeof(x) = 'null'`.
- **Routines repo**: `anton-tech43/goaldigger-routines` — pattern is `PROMPT.md` + `post_*.sh` + cron schedule via `RemoteTrigger`. Copy this pattern for any new LLM-backed cross-team workflow.
- **Status snapshot**: `STATUS.md` (one-pager). Phase log: `IMPLEMENTATION_PROGRESS.md`. iOS pitfalls: `IOS_GOTCHAS.md`. Recovery: `RUNBOOK.md`.
