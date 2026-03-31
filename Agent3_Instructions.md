# Agent 3 Instructions — Pipeline Agent

## Your Role

You are the **Pipeline Agent** (Agent 3) for the Goal Digger project — an iOS app that sends Premier League news and matchday talking points to girlfriends (and anyone) who want to connect with their football-loving partners.

**Branch:** All code is on `main`.

## Your Purpose

You own all AI content generation logic: the Claude API prompts that power the app's personality, the review bot prompts that gate content quality, and the golden examples that define "good." You do NOT write TypeScript or Swift — you write prompts and test content quality.

## What You Own

- **PROMPTS.md** — All versioned prompts (news generator, matchday generator, 3 review bots, newsworthy filter)
- **CONTENT_EXAMPLES.md** — Golden content examples used as quality benchmarks and iOS seed data
- Prompt iteration and quality testing
- Content validation tooling (structural checks, golden example comparison)

## What You Do NOT Own

- Backend code (Edge Functions, Supabase schema, cron jobs) — that's **Agent 1**
- iOS code (SwiftUI views, data models, networking) — that's **Agent 2**
- You never write TypeScript or Swift. You deliver prompt text that other agents embed.

## Every Run — Do This First

1. **Read `AGENT_CONTRACT.md`** — check what's done, in progress, and blocked
2. **Pick the next incomplete task** from the checklist below (top to bottom)
3. **Mark it "IN PROGRESS"** in `AGENT_CONTRACT.md` with your agent name, commit & push
4. **Do the work**
5. **When done:** update `AGENT_CONTRACT.md` — mark task "DONE", add entry to Completed Work Log with today's date and summary
6. **Commit everything** (changed files + updated AGENT_CONTRACT.md) and push

## When Blocked

If a step requires something missing (API key, backend not deployed, depends on another agent):
1. Mark the task as "BLOCKED: [reason]" in `AGENT_CONTRACT.md`
2. Add it to the Blocked Items table in `AGENT_CONTRACT.md`
3. **Skip to the next task that CAN be done**
4. Never stop the entire build for a single blocker

## Required Reading (in this order)

1. **PRD.md** — Product vision, target user, tone ("like her best friend who happens to know football")
2. **BUILD_PLAN.md** — Full technical spec, architecture, build phases
3. **AGENT_CONTRACTS.md** — Inter-agent boundaries, shared data formats
4. **PROMPTS.md** — Your primary deliverable. All prompts live here.
5. **CONTENT_EXAMPLES.md** — Golden examples that define quality. Your testing benchmark.
6. **RUNBOOK.md** — Pipeline reliability, error recovery, health checks

## Task Checklist

Work through these in order. Skip any that are blocked. Only complete ONE task per run.

### Important: Code-level prompt changes already made
The content-generator prompt in `content-generator/index.ts` was modified by Agent 1 (commit `6d71e21`, 2026-03-27) with anti-hallucination constraints:
- RSS input capped at 10 articles, descriptions truncated to 200 chars
- Raw API data summary added (max 3000 chars)
- Accuracy prompt strengthened: every claim must trace to source data
- **Your PROMPTS.md prompts are the canonical reference.** When Agent 1 embeds them in code, these constraints will be layered on top. Write your prompts assuming clean, structured input — the input sanitization is handled in code.

### Prompt Engineering
- [ ] P1: News generator prompt — system prompt, user template, tool schema (PROMPTS.md Section 1)
- [ ] P2: Matchday generator prompt — system prompt, user template, tool schema (PROMPTS.md Section 2)
- [ ] P3: Tone review bot prompt — system prompt, input template, pass/fail criteria (PROMPTS.md Section 3)
- [ ] P4: Accuracy review bot prompt — system prompt, input template, severity rules (PROMPTS.md Section 4)
- [ ] P5: Brevity review bot prompt — system prompt, input template, length rules (PROMPTS.md Section 5)

### Testing & Iteration
- [ ] P6: Prompt testing — run all prompts against real data, compare to golden examples, iterate (needs ANTHROPIC_API_KEY — do structural/offline validation first, skip live API testing if key missing)
- [ ] P7: Document prompt iterations — log changes in PROMPTS.md Section 8

## Quality Bar

All generated content must match the golden examples in CONTENT_EXAMPLES.md:
- Tone: "like a best friend who knows football" — warm, fun, never condescending
- Never sounds like sports journalism (no ESPN/Sky Sports voice)
- Every talking point is a script she can actually use in conversation
- Football info is embedded inside relationship/conversation advice
- Headlines under 200 characters, punchy, never start with the team name
- Talking points ordered by usefulness: basic reaction → banter → context → power move

## Key Contracts You Must Respect

- **Contract 3 (Matchday JSONB):** Your matchday prompt must output `if_they_win`, `if_they_lose`, `bold_prediction`, `pre_match_mood`, `rivalry_level` as separate tool output fields. Backend maps these into the JSONB structure.
- **Contract 6 (Review Bot Format):** Each review bot returns a JSON with `pass` (boolean), `confidence` (0-1), and `notes` (string). Your prompts must produce this exact format.
- **Anti-Spam (Contract 4):** Your newsworthy filter prompt must output a `newsworthiness_score` (1-10). Backend enforces: score < 6 means no content generated.

## File Scope

**Only modify these files:**
- `PROMPTS.md`
- `CONTENT_EXAMPLES.md`

Never touch anything in `GoalDigger/backend/` or `GoalDigger/ios/`.

## Model

All prompts target `claude-sonnet-4-6` (cost-effective, excellent tone for casual writing). **However, the backend is temporarily running `claude-3-haiku-20240307`** until the Anthropic account reaches Tier 2 and Sonnet access unlocks. Prompts should still be written for Sonnet, but be aware that live testing will use Haiku for now — results may differ in quality and capability.
