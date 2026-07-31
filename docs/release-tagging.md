# Release tagging convention (`HCF_RELEASE`)

pb-hcf's verification spine (bugsink + magento2-sentry + issue-sentinel) needs every error
event tagged with the plan/batch that produced it, so `issue-sentinel` can ask "issues
`first_seen` since this batch started, for this project + this release" instead of grepping
`var/log`. `HCF_RELEASE` is the single env var that carries that tag end to end.

## Format

```
HCF_RELEASE=<plan-name>#<batch-n>
```

- `<plan-name>` — the plan directory slug under `.claude/plans/` (e.g. `v0-5-0-verification-spine`).
- `<batch-n>` — the orchestrator's batch counter for the current run (e.g. `3`).
- Example: `HCF_RELEASE=v0-5-0-verification-spine#3`

## Who sets it

`HCF_RELEASE` is exported by the plan-orchestrate wrapper/env at the start of each batch —
not hand-set per project. Any process reading it (magento2-sentry config, issue-sentinel) treats
it as ambient environment, not a value it computes itself.

## Who consumes it

- **`justbetter/magento2-sentry`** reads `HCF_RELEASE` into its `release` config value (alongside
  the DSN from `~/.pb-hcf/bugsink.env` and `environment: ddev`) — see
  `services/bugsink/README.md` → "Magento project wiring". Every error event Bugsink ingests
  during that batch carries this release tag.
- **`issue-sentinel`** filters Bugsink's canonical API query on `release=<HCF_RELEASE>` (plus
  `project=<id>` and `first_seen >= batch-start`) so it only ever sees issues introduced by the
  batch under review, not pre-existing/unrelated noise.

## Fallback when unset

If `HCF_RELEASE` is not set in the environment (e.g. manual/ad-hoc runs outside plan-orchestrate,
or local debugging), fall back to the current git short SHA:

```bash
RELEASE="${HCF_RELEASE:-$(git rev-parse --short HEAD)}"
```

This keeps every Bugsink event taggable even outside an orchestrated batch — a short SHA is
always resolvable in a git checkout — but loses the plan/batch granularity, so `issue-sentinel`
falls back to filtering by SHA + `first_seen` window instead of `<plan-name>#<batch-n>`.
