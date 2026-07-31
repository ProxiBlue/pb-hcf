# Task 009: issue-sentinel agent + magento2-sentry install doc

**Status**: completed
**Depends on**: 002, 008
**Retry count**: 0

## Description
New enrollable agent agents/issue-sentinel.md: after each batch, query central Bugsink for issues first_seen since batch start (project + HCF_RELEASE filtered), triage via bricklayer diagnose-error where reachable, PUSHBACK with event + stacktrace; thin log fallback for SDK-invisible noise. Plus templates/sentry/README.md documenting per-project justbetter/magento2-sentry install.

## Context
- **Enrollment convention (VERIFIED):** source ships DORMANT — no `phase/order/mode`. Body prose documents "You run at post-batch, order 30, mode single — first agent enrolled at this hook." Task 014 registers the triple in the wire enrollable table. (Adding post-batch also means task 014 must add post-batch to the plugin.json/marketplace.json hook-point list, currently missing it.)
- **Depends on task 002** for the bricklayer wires.json entry shape it reads when deciding whether to run bricklayer diagnose-error (graceful skip if bricklayer entry absent/reachable=false).
- **Evidence artefact:** write `_issue_sentinel.md` (or append per-batch) into the plan dir recording the verdict per batch (PASS / PUSHBACK list) — this is BOTH the batch marker and pipeline-audit's proof this agent fired. The start-of-batch timestamp marker may live in the same file's header.
- Query: GET $BUGSINK_URL_CONTAINER/api/canonical/0/issues/?project=<id> Bearer-authed; filter first_seen > batch-start timestamp (agent records its own start-of-batch marker file in plan dir) and release match per docs/release-tagging.md
- Triage: for each new issue, if bricklayer wired (wires.json) run diagnose-error to correlate DI/plugin state; PUSHBACK = issue friendly_id + calculated_type/value + stacktrace excerpt + suspected file:line
- Log fallback (always, cheap): new files in var/report/ since marker + last N lines of cron.log stderr patterns; NOT full log tailing — Bugsink owns that
- Degrade: wires.json bugsink reachable=false → skip API, log-fallback only, note the gap; never block
- templates/sentry/README.md: composer require justbetter/magento2-sentry, env.php config keys (dsn from ~/.pb-hcf/bugsink.env, environment ddev, release from HCF_RELEASE), verification curl

## Requirements (Test Descriptions)
- [x] `it ships DORMANT with no phase/order/mode in source frontmatter and documents intended post-batch order-30 single enrollment in the body prose` — frontmatter has only `name`/`description`/`tools`; body prose states `phase: post-batch`, `order: 30`, `mode: single`, first agent enrolled at post-batch.
- [x] `it writes _issue_sentinel.md verdict/marker to the plan dir every batch including PASS and degraded runs` — Step 6 mandates the write "every run, no exceptions"; PASS, PUSHBACK, and degraded (PASS-with-note/PUSHBACK-with-note) verdict blocks all included.
- [x] `it filters issues by first_seen after batch start and by HCF_RELEASE when set` — Step 4 filters `first_seen >= marker` AND release match; Step 2 resolves `RELEASE="${HCF_RELEASE:-$(git rev-parse --short HEAD)}"` per docs/release-tagging.md.
- [x] `it triages via bricklayer diagnose-error only when wires.json marks bricklayer reachable` — Step 5 gates `vendor/bin/bricklayer diagnose-error` on `jq '.playbooks[] | select(.name=="bricklayer") | .reachable'` from `.claude/wires.json`; absent/false entry = skip.
- [x] `it returns PUSHBACK with friendly_id type value and stacktrace excerpt per new issue` — Step 6 PUSHBACK template: `Issue <friendly_id> — <calculated_type>: <calculated_value>`, stacktrace excerpt, suspected file:line.
- [x] `it falls back to var/report and cron stderr scan when bugsink unreachable` — Step 5b always runs the cheap `var/report` + cron-stderr scan; Step 3 gates the API path only, degraded verdict block documents log-fallback-only mode.
- [x] `it ships templates/sentry/README.md with composer install and env.php release wiring` — new `templates/sentry/README.md`: `composer require justbetter/magento2-sentry`, `env.php` `sentry` block with `dsn`/`environment`/`release` keys sourced from `~/.pb-hcf/bugsink.env` and `HCF_RELEASE`, plus verification curl.

## Acceptance Criteria
- PASS on zero new issues; PUSHBACK never fires on issues predating the batch marker

## Implementation Notes
- New file `agents/issue-sentinel.md`: ships dormant (name/description/tools frontmatter only,
  no phase/order/mode), documents intended `post-batch`/`order: 30`/`mode: single` enrollment
  and "first agent enrolled at post-batch" in prose (per task context, task 014 will also need
  to add `post-batch` to the plugin/marketplace hook-point list — not this task's scope).
- Rolling batch-start marker convention: no separate marker file — the marker lives as a
  `Batch-start marker: <ISO-8601>` header line inside `_issue_sentinel.md` itself, read at the
  start of each run and rewritten at the end. First run (no prior marker) falls back to the plan
  dir's own creation time, not epoch-0, so a fresh plan never pulls in Bugsink's full history.
- Bugsink query filters on both `first_seen >= marker` and `release == $RELEASE`
  (`HCF_RELEASE` or git-short-SHA fallback per `docs/release-tagging.md`).
- Bricklayer triage (Step 5) and the Bugsink API path (Step 3) are both gated independently on
  `.claude/wires.json` `reachable` flags (`bricklayer` / `bugsink` entries respectively) —
  neither ever blocks the batch; both degrade with a note.
- Log fallback (Step 5b: `var/report/` new files + cron.log stderr grep) runs unconditionally
  every batch as a cheap cross-check, and becomes the sole signal when Bugsink is unreachable.
- New file `templates/sentry/README.md`: `composer require justbetter/magento2-sentry` install,
  `env.php` `sentry` config block (`dsn` from `SENTRY_DSN` env var sourced from
  `~/.pb-hcf/bugsink.env`'s `BUGSINK_DSN_<PROJECT>`, `environment: ddev`, `release` from
  `HCF_RELEASE`), and a verification curl against the Bugsink canonical API. No secret values
  committed anywhere — env var names only.
- Verified via targeted grep assertions per requirement (frontmatter parse + absence of
  phase/order/mode; batch-start marker, first_seen, HCF_RELEASE, bricklayer-gating, PUSHBACK
  format, var/report+cron fallback, PASS-on-zero, `_issue_sentinel.md` artefact-write strings
  all present) and the repo-wide secrets grep (`grep -rE '(ff15ea68|9c111c47)' --exclude-dir=.git .`)
  returns 0 hits in the two new deliverable files (pre-existing hits elsewhere are literal
  documentation of the grep command itself in prior tasks' notes/testing.md, not real secrets —
  untouched by this task).
- Did not edit README.md at repo root (task 014 owns it) or the wire enrollable-agent table
  (also task 014).
