# OTel — Claude Code telemetry, fleet-wide

Host-level singleton (same pattern as `services/bugsink`): one collector,
every ddev project's `claude` CLI process exports into it, one set of
resource attributes per project so dashboards can slice by project and
by model tier.

**Scope for pb-hcf 0.5.0: docs + env template only.** No collector compose
file ships in this repo yet — `templates/otel/otel.env.dist` documents
the client (Claude Code) side, and this README documents how to stand
up *a* collector (any of the options below) so that template has
somewhere to point. Collector deployment/hardening/persistence is
deferred to a later task.

## Why this exists

`CLAUDE_CODE_ENABLE_TELEMETRY` turns Claude Code into an OTLP emitter of
metrics, logs, and (beta) traces. Per-project token/cost data currently
only lives in the terminal's own session summary — no fleet-wide view.
Pointing every project's `claude` process at one host collector gives
one dashboard for "which project/model tier is burning tokens", the
same way Bugsink gives one dashboard for "which project is erroring".

**Tie-in**: the model-tiering rule (`~/claude-skills-central/rules/model-tiering.md`)
picks haiku/sonnet/opus per task type on cost/capability tradeoffs —
this is the consuming use case for the per-tier cost metric described
below; without it, tiering decisions are made blind.

## Verified env vars (checked 2026-07-31 against
https://code.claude.com/docs/en/monitoring-usage)

| Var | Purpose |
|---|---|
| `CLAUDE_CODE_ENABLE_TELEMETRY` | Master switch (`1` to emit) |
| `OTEL_METRICS_EXPORTER` | `otlp` \| `prometheus` \| `console` \| `none` |
| `OTEL_LOGS_EXPORTER` | `otlp` \| `console` \| `none` |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | `grpc` \| `http/protobuf` \| `http/json` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | Collector address (e.g. `http://host.docker.internal:4317`) |
| `OTEL_EXPORTER_OTLP_HEADERS` | Optional auth header for the collector |
| `OTEL_RESOURCE_ATTRIBUTES` | Comma-separated `key=value`, no spaces — project/user identification |

Full var list and semantics: see the docs URL above (re-verify at
implementation time if this drifts — Anthropic revises this page).
Template with these values pre-filled: `templates/otel/otel.env.dist`.

## Target dashboards: per-project tokens and cost

The metric that matters for this fleet is **per-project token and cost
usage, broken down by model tier**. Claude Code emits this as:

- `claude_code.token.usage` (tokens, attributes include `type`:
  input/output/cacheRead/cacheCreation and `model`)
- `claude_code.cost.usage` (USD, per session)

Both carry the standard resource attributes, including whatever you set
via `OTEL_RESOURCE_ATTRIBUTES` (e.g. `project.name=<PROJECT_NAME>`) —
that's the join key across dashboards. A useful first dashboard is a
table of `sum(claude_code.token.usage) by (project.name, model)` next
to `sum(claude_code.cost.usage) by (project.name, model)`, so it's
obvious at a glance whether a project is running too much work on a
higher tier than its tasks need.

## Host-singleton collector pattern

Mirrors `services/bugsink`: one instance on the host, every project's
in-container `claude` process points at it via `host.docker.internal`.
Pick one backend — this repo doesn't mandate one, since it's out of
scope for 0.5.0:

- **SigNoz** — self-hosted, ships its own OTLP collector + ClickHouse +
  UI in one compose stack; closest match to the Bugsink "one container
  set, batteries included" experience. Good default if you want traces
  too (Claude Code's trace export is beta).
- **Langfuse** — LLM-observability-first UI (prompt/response viewer,
  cost breakdown by model out of the box), OTLP-compatible ingest.
  Good default if the token/cost-by-model dashboard above is the
  primary use case and you don't need generic infra tracing.
- **Plain `otel-collector` → file/Prometheus** — lowest-effort option:
  run the vendor-neutral `otel/opentelemetry-collector` image with a
  `file` or `prometheus` exporter, no UI. Good for a quick smoke test
  or for piping into an existing Prometheus/Grafana stack.

Minimal inline snippet for the third option (NOT a shipped compose
file — copy/adapt, don't `docker compose up` this directory):

```yaml
# services/otel/otel-collector.yml (example only, not committed as a service)
services:
  otel-collector:
    image: otel/opentelemetry-collector:latest
    command: ["--config=/etc/otel-collector.yml"]
    volumes:
      - ./otel-collector.yml:/etc/otel-collector.yml
      - ./out:/out
    ports:
      - "4317:4317" # OTLP gRPC
      - "4318:4318" # OTLP HTTP
```

```yaml
# otel-collector.yml (example only)
receivers:
  otlp:
    protocols:
      grpc:
      http:
exporters:
  file:
    path: /out/claude-code-metrics.jsonl
service:
  pipelines:
    metrics:
      receivers: [otlp]
      exporters: [file]
```

## Enabling telemetry on a project

1. Copy `templates/otel/otel.env.dist` to the project (e.g.
   `.ddev/claude-code/.claude/otel.env`), replace `<PROJECT_NAME>`.
2. Point `OTEL_EXPORTER_OTLP_ENDPOINT` at whichever collector you stood
   up from the options above.
3. Source the env file before the `claude` CLI process starts (same
   entrypoint the project already uses for `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`,
   per the fleet-wide `commands/web/claude` wrapper convention).
4. Confirm data is flowing: check the collector's own ingest log/UI, or
   for the file exporter above, `tail -f out/claude-code-metrics.jsonl`.

That's the full loop this doc claims to support: a future session can
enable telemetry on any project from this file alone, without needing
to re-derive var names or the collector shape from scratch.
