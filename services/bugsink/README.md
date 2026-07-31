# Bugsink — central error tracking for pb-hcf issue-sentinel

Host-level singleton (Neo4j/graphiti + chatroom pattern): one instance, all ddev
projects report into it, one Bugsink project/DSN per ddev project.

## Why Bugsink

Sentry-SDK-compatible, single container, SQLite — vs self-hosted Sentry's 30-container
stack. Fingerprint grouping + `first_seen` + `release` tagging replace log
baseline-diffing entirely: the issue-sentinel agent asks "issues first_seen > batch
start for this project + release" instead of grepping `var/log`.

## Run (host)

```bash
cd services/bugsink
BUGSINK_SECRET=$(cat ~/.bugsink-secret) docker compose up -d
```

- UI: http://localhost:7788 — superuser `lucas@proxiblue.com.au` (initial password
  `admin`, set via `CREATE_SUPERUSER` on first boot — change it in the UI).
- Secrets + DSN registry + API token: `~/.pb-hcf/bugsink.env` (mode 600, NOT in git).
- Data: docker volume `bugsink_data` (SQLite). Include in host backup regime.

## Add a project (per ddev project)

```bash
docker exec bugsink bugsink-manage shell -c "
from projects.models import Project
from teams.models import Team
t, _ = Team.objects.get_or_create(name='fleet')
p, _ = Project.objects.get_or_create(name='<ddev-project>', team=t)
print(p.dsn)"
```

Append the DSN to `~/.pb-hcf/bugsink.env` as `BUGSINK_DSN_<PROJECT>` (swap
`localhost` for `host.docker.internal` for in-container use).

## Magento project wiring

```bash
composer require justbetter/magento2-sentry
```

Config (env.php or admin): DSN from the registry, `environment: ddev`,
`release`: plan/batch id (wired by HCF orchestration — pb-hcf v0.5.0).

## Query API (what issue-sentinel calls)

```bash
source ~/.pb-hcf/bugsink.env
curl -H "Authorization: Bearer $BUGSINK_API_TOKEN" \
  "$BUGSINK_URL_CONTAINER/api/canonical/0/issues/?project=<id>"
```

Returns issues with `first_seen`, `last_seen`, `calculated_type/value`,
event counts, `is_resolved`. OpenAPI schema: `/api/canonical/0/schema/swagger-ui/`.

Token minted via: `docker exec bugsink bugsink-manage shell -c "from bsmain.models import AuthToken; print(AuthToken.objects.create().token)"`

## Wire integration

`/pb-hcf:wire` probes this service on every wire / re-wire / `--reprobe` run — see the
`bugsink` row in `skills/wire/SKILL.md`'s "Per-playbook reachability probes" table. It sources
`BUGSINK_URL_CONTAINER` and `BUGSINK_API_TOKEN` from the env file (never hardcodes them),
curls `$BUGSINK_URL_CONTAINER/api/canonical/0/` with the bearer token, and treats HTTP `200`
**or** `401` as reachable (both prove the service answered) — only connection-refused/timeout
is recorded as unreachable. It also checks for a `BUGSINK_DSN_<PROJECT>` var in the same env
file as a separate DSN-presence signal. The result lands in `.claude/wires.json` as a
`playbooks[]` entry named `bugsink` with `details.endpoint` and `details.projectDsnVar`.

Release tagging (`release` config value read by `justbetter/magento2-sentry`, filtered on by
`issue-sentinel`) follows the `HCF_RELEASE` convention — see `docs/release-tagging.md`.

## Smoke-tested 2026-07-30

Store API ingest (HTTP 200) → grouped as issue `PPS-1` → queryable via canonical
API with release + first_seen intact. Full loop verified.
