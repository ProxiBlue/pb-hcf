# Task 013: OTel env template + services/otel README

**Status**: pending
**Depends on**: none
**Retry count**: 0

## Description
Document Claude Code OTLP telemetry for the fleet: templates/otel/otel.env.dist (CLAUDE_CODE_ENABLE_TELEMETRY, OTEL_METRICS_EXPORTER, OTEL_EXPORTER_OTLP_ENDPOINT pointing at host collector, resource attrs project/user) + services/otel/README.md (collector options SigNoz vs Langfuse vs plain otel-collector→file, mirror-of-bugsink singleton pattern, what metrics matter: tokens/cost per project, per model tier). Docs + env only — no collector implementation.

## Context
- Verify env var names against current Claude Code docs at implementation time (claude-code-guide agent or docs); encode verified names with check date
- Pattern: services/bugsink/ (compose optional here — README may show a minimal otel-collector compose snippet inline)
- Tie-in: model-tiering rule wants per-tier cost data; note this as the consuming use case

## Requirements (Test Descriptions)
- [ ] `it ships templates/otel/otel.env.dist with verified current env var names and a check date`
- [ ] `it documents the host-singleton collector pattern with at least one concrete backend option`
- [ ] `it names per-project token and cost metrics as the target dashboards`
- [ ] `it states clearly that collector deployment is out of scope for 0.5.0`

## Acceptance Criteria
- A future session can enable telemetry on any project from this doc alone
