# Task 009: issue-sentinel agent + magento2-sentry install doc

**Status**: pending
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
- [ ] `it ships DORMANT with no phase/order/mode in source frontmatter and documents intended post-batch order-30 single enrollment in the body prose`
- [ ] `it writes _issue_sentinel.md verdict/marker to the plan dir every batch including PASS and degraded runs`
- [ ] `it filters issues by first_seen after batch start and by HCF_RELEASE when set`
- [ ] `it triages via bricklayer diagnose-error only when wires.json marks bricklayer reachable`
- [ ] `it returns PUSHBACK with friendly_id type value and stacktrace excerpt per new issue`
- [ ] `it falls back to var/report and cron stderr scan when bugsink unreachable`
- [ ] `it ships templates/sentry/README.md with composer install and env.php release wiring`

## Acceptance Criteria
- PASS on zero new issues; PUSHBACK never fires on issues predating the batch marker
