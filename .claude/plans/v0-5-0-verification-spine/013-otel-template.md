# Task 013: OTel env template + services/otel README

**Status**: completed
**Depends on**: none
**Retry count**: 0

## Description
Document Claude Code OTLP telemetry for the fleet: templates/otel/otel.env.dist (CLAUDE_CODE_ENABLE_TELEMETRY, OTEL_METRICS_EXPORTER, OTEL_EXPORTER_OTLP_ENDPOINT pointing at host collector, resource attrs project/user) + services/otel/README.md (collector options SigNoz vs Langfuse vs plain otel-collector→file, mirror-of-bugsink singleton pattern, what metrics matter: tokens/cost per project, per model tier). Docs + env only — no collector implementation.

## Context
- Verify env var names against current Claude Code docs at implementation time (claude-code-guide agent or docs); encode verified names with check date
- Pattern: services/bugsink/ (compose optional here — README may show a minimal otel-collector compose snippet inline)
- Tie-in: model-tiering rule wants per-tier cost data; note this as the consuming use case

## Requirements (Test Descriptions)
- [x] `it ships templates/otel/otel.env.dist with verified current env var names and a check date`
- [x] `it documents the host-singleton collector pattern with at least one concrete backend option`
- [x] `it names per-project token and cost metrics as the target dashboards`
- [x] `it states clearly that collector deployment is out of scope for 0.5.0`

## Acceptance Criteria
- A future session can enable telemetry on any project from this doc alone

## Implementation Notes
- Verified env var names via `curl` fetch of https://code.claude.com/docs/en/monitoring-usage
  on 2026-07-31 (WebFetch tool unavailable in this session; used Bash+curl instead as
  equivalent doc-check). Confirmed: `CLAUDE_CODE_ENABLE_TELEMETRY`, `OTEL_METRICS_EXPORTER`,
  `OTEL_LOGS_EXPORTER`, `OTEL_EXPORTER_OTLP_PROTOCOL`, `OTEL_EXPORTER_OTLP_ENDPOINT`,
  `OTEL_EXPORTER_OTLP_HEADERS`, `OTEL_RESOURCE_ATTRIBUTES`, and metric names
  `claude_code.token.usage` / `claude_code.cost.usage` all present in current docs.
- `templates/otel/otel.env.dist`: 6 non-comment lines, each `KEY=value` no spaces, check-date
  comment at top.
- `services/otel/README.md`: mirrors `services/bugsink/README.md` tone (host-singleton framing,
  numbered run/enable steps). Lists SigNoz / Langfuse / plain otel-collector→file as concrete
  backend options (3, satisfies "at least one"). States 0.5.0 scope is docs+env only, collector
  deployment deferred. Names `claude_code.token.usage` + `claude_code.cost.usage` as target
  dashboard metrics, broken down by project (via `OTEL_RESOURCE_ATTRIBUTES`) and model. Ties
  into model-tiering rule as the consuming use case. Inline otel-collector compose+config
  snippet included as an illustrative example only (commented as "not committed as a service"),
  per task allowance — no compose file shipped in services/otel/.
- Did not touch repo-root README.md (reserved for task 014).
