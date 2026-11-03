# Vendored: Cloudflare security-audit skill

| | |
|---|---|
| Source | https://github.com/cloudflare/security-audit-skill |
| Commit | `c1c8a8c1471069fb0e188eeaff69b8e8db6564a8` (tarball via `gh api repos/cloudflare/security-audit-skill/tarball/<commit>`) |
| License | MIT, Copyright (c) 2025-2026 Cloudflare, Inc. (`LICENSE`, kept unmodified) |
| Vendored | 2026-11-03, for the `bug-hunt` skill (approved by Anton the same day) |
| Modified | **Nothing.** Every file below is byte-identical to the upstream commit. Our adaptations live in `../../SKILL.md`, never in these files. |

## What was reviewed

All 22 upstream files were read in full before anything was copied, treating them
as untrusted data. The four `.cjs` files were read line by line:

- `validate-findings.cjs`, `validate-coverage-ledger.cjs`: use only `fs`, `path`
  and `util`. They open the one file given as an argument read-only (no-follow,
  nonblocking, 5 MiB cap), print a verdict and exit. No network, no writes, no
  child processes, no `eval`, no environment reads.
- `*.test.cjs`: write only inside `fs.mkdtempSync(os.tmpdir())` directories they
  delete in `finally`; spawn only `process.execPath` (node itself, on the
  validators) and `mkfifo` inside that temp directory. No network.
- Run on 2026-11-03 with Node 24.14.1 and `TMPDIR` pointed at the session
  scratchpad: **65 tests, 65 pass**. Rerun after any update:
  ```bash
  TMPDIR=<scratch> node --test .claude/skills/bug-hunt/vendor/cloudflare-security-audit/*.test.cjs
  ```

## What is kept, and what we use it for

| File | sha256 (first 12) | Used for |
|---|---|---|
| `SKILL.md` | `5e3e96a1e438` | The method, core principles, severity anchors, anti-patterns |
| `RECONNAISSANCE.md` | `02ca887aca84` | Phase 1 recon prompts (1a–1d), entry-surface inventory |
| `HUNTING.md` | `71c121decea1` | Phase 2: core hunting method, candidate gate, coverage critic |
| `ATTACK-CLASSES.md` | `3ee4f00c6e8c` | Ordinary classes, incl. Business logic, Wildcard, Obvious things |
| `VALIDATION-AND-REPORTING.md` | `b892470cb89b` | Phase 3 verifier prompt (disprove each candidate), report shape |
| `AI-AND-LLM.md` | `7335a95c4355` | Routines: RSS/news into a model that holds Bash and a service key |
| `DATA-ISOLATION-AND-LIFECYCLE.md` | `307dcb3e24d2` | RLS, anon reads, Delete My Data, retention, derived copies |
| `DESKTOP-MOBILE-AND-LOCAL-IPC.md` | `58eae8ee0ca6` | iOS app, widget/Live Activity, NSE, App Group, push actions, restore |
| `PROTOCOLS-RPC-AND-MESSAGING.md` | `8b73816fa5b3` | PostgREST RPCs, cron to Edge calls, APNs, duplicate/out-of-order delivery |
| `RESOURCE-EXHAUSTION-AND-AVAILABILITY.md` | `4326fab5c92a` | API-Football cap, Anthropic spend, pg_net, token floods |
| `SUPPLY-CHAIN-AND-RELEASE.md` | `f372e919940e` | Facebook SDK, Deno std/npm pins, routines repo, TestFlight builds |
| `CLOUD-AND-DEPLOYMENT.md` | `3c80f3088be2` | Edge Functions `--no-verify-jwt`, secrets, Vault, exposed schemas |
| `WEB-PROTOCOL-AND-AUTH.md` | `4f3066dffa23` | API-key scope (publishable vs secret), the custom caller gate |
| `report-schema.json` | `6575c9de4a62` | Shape of `findings.json` |
| `validate-findings.cjs` (+ test) | `e85f232e36bf` | Validates `findings.json` (reads the schema from its own folder) |
| `validate-coverage-ledger.cjs` (+ test) | `2eb280bd2e33` | Kept so the findings test (which checks the two stay aligned) runs; also usable for a `deep` run's JSON ledger. A normal hunt uses the CSV ledger in `../../SKILL.md` |
| `LICENSE` | `e598e694aa50` | MIT notice, required |

## What was left out, and why

| Upstream file | Why not |
|---|---|
| `README.md` | Install line (`npx skills add …`) we must not run; its file table is covered here |
| `CLIENT-SIDE.md` | No browser surface: no WKWebView, no SFSafariViewController, no web app in this repo (2026-11-03 grep) |
| `MEMORY-SAFETY-AND-BINARY.md` | Swift and TypeScript only, no C/C++/unsafe native code of ours |

Kept files still link to the two left-out companions; those links are dead here on
purpose.

## Where we deviate from upstream (decided in `../../SKILL.md`)

- Upstream forbids touching deployed systems. We run **read-only** SQL against the
  production database (`BEGIN READ ONLY … ROLLBACK` through `scripts/sql.sh`) and a
  **GET-only probe with the publishable key that ships in the app** against our own
  Supabase project, as `SECURITY_PROBE_2026-10-07.md` did. Owner-authorized, no
  writes, no volume, no scanners.
- Upstream writes its run outside the repo. Our working files go to the session
  scratchpad; only the redacted report and `findings.json` are committed under
  `docs/bug-hunt/`.
- Upstream's OS-sandbox and artifact-promotion procedure is not reproduced. Our
  local execution is limited to our own code: `deno test`, the iOS build, scratch
  harnesses that import shipped functions, and a per-agent simulator.
- Upstream uses a JSON coverage ledger with canonical IDs; a normal hunt uses a CSV
  ledger (`entry-points.csv`) with the same coverage gate.

## Updating

Fetch the new commit into a fresh empty scratch directory, diff it against these
files, read every changed file (the `.cjs` in full), rerun the tests, then update
the commit, date and hashes above in the same change.
