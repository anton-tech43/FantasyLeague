# docs/archive — the V1 documents

Eighteen documents that describe a version of GoalDigger that no longer exists.
They each say so in their own first line, and they stayed in the repository root
until 2026-10-08, mixed in with the current docs — which is the problem, because
they are alphabetically first and a newcomer opens them first.

**Nothing reads these at runtime.** Checked before the move: 140 mentions across
both repositories, every one of them prose or a code comment, zero file opens.
References from documents that stayed were rewritten to point here.

## Why they are kept rather than deleted

They are the only record of designs that were considered, and three of them are
cited by migrations that are still applied. Deleting them would make a commit
message like "see PRD §3.2" unresolvable.

## What they get wrong

Read `ARCHITECTURE.md` instead. The specific trap: **`PRD.md`,
`AGENT_CONTRACTS.md` and `PROMPTS.md` describe the Edge `content-generator` →
`content-reviewer` chain as the content pipeline.** It is gated off behind a
secret that is not set and has produced nothing for months. Live content comes
from the claude.ai routines in `anton-tech43/goaldigger-routines`, which bill a
flat subscription rather than per token — a difference of real money.

Two other things the V1 docs get wrong: the app follows **20 Premier League
clubs**, up to two per device, not "3 teams"; and the World Championship is
retired, with every country row inactive behind `CountryFollowing.isEnabled`.

## The files

| File | Was |
|---|---|
| `PRD.md`, `PRODUCT_BRIEF_INTEGRATION.md`, `BUILD_PLAN.md` | the original product and build plan |
| `AGENT_CONTRACTS.md`, `PROMPTS.md`, `CONTENT_EXAMPLES.md` | the Edge pipeline's agent contracts and prompts |
| `APP_STORE_STRATEGY.md`, `APP_STORE_V2.0_*.md` (3), `WHATS_NEW_2.0.3.md` | the 2.0 store submission |
| `V1.1_FEATURE_BUNDLE.md`, `V2.1_DESIGN_SECONDARY_ALERT.md`, `V2.1_DESIGN_VAULT_SPLIT.md`, `V2.2_DESIGN_MULTI_TEAM.md` | per-release designs; the multi-team one did ship |
| `WC_GROUP_STAGE_DESIGN.md`, `WC_ROUTINES_HANDOFF.md`, `WC_TEST_REPORT.md` | the 2026 World Cup |

`V2.1_DESIGN_SECONDARY_ALERT.md` and `V2.1_DESIGN_VAULT_SPLIT.md` are designs
that were never implemented, and `WC_TEST_REPORT.md` is a report nothing cites.
Those three are the candidates if this directory is ever trimmed further.
