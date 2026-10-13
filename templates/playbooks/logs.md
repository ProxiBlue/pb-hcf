# logs — uat/prod server + app logs (VictoriaLogs)

**Authority scope:** everything the servers wrote that is NOT a captured
exception — HTTP status/latency per URL, nginx + php-fpm errors, PHP slow-log
traces, MySQL slow queries, app logs (Magento `var/log/*.log`), supervisor.
Bugsink (`.claude/bugsink.md`) owns stack traces; this owns the traffic and
log lines around them. **Ask Bugsink first for an exception, then this for
context** (what URL, how often, what else was logging at that moment).

This replaces SSHing to uat/live to read logs. There is no dev/ddev tenant:
local logs stay in the container (`var/log/*.log`, `.ddev/uvicorn.log`).

## Access — two MCP servers, one per environment

| MCP server | env | token (container env) |
|---|---|---|
| `logs-uat`  | uat  | `LOGS_READ_TOKEN_UAT`  |
| `logs-prod` | prod | `LOGS_READ_TOKEN_PROD` |

Both come from the fleet `mcp.json`. Tenant is forced server-side from the
bearer token, so `logs-uat` can only ever return uat rows — the server name IS
the environment boundary (same idea as one Bugsink project per env).
Read-only: read tokens can only hit the LogsQL select API.

Onboarding a project: mint a read token per env, add
`LOGS_READ_TOKEN_UAT=$LOGS_R_<PROJ>_UAT` / `_PROD` to `.ddev/config.yaml`
`web_environment` (on the LIVE branch), restart ddev. Every call returning
403 → token unset/unknown in this container; say so and skip, never guess at
log state.

MCP tools unavailable (headless `claude --print`)? Same query over curl
against the log host's `/select/logsql/query` with
`Authorization: Bearer $LOGS_READ_TOKEN_<ENV>` and `--data-urlencode 'query=…'`.

## What's in it

Stream fields: `project`, `env` (`uat`|`prod`), `source`. Exact sources and
per-source fields are whatever this project's Vector config ships — list them
before guessing:

```logsql
_time:24h | stats by (source) count() n
```

Typical Hypernode set: `nginx_access`, `nginx_error`, `php_fpm`, `php_slow`,
`mysql_slow`, `magento` (field `file`), `supervisor`. Varnish chain: a cache
MISS logs twice — check for a `hop` field (`front`|`backend`); `backend` =
reached PHP. If the access line is a compact `_msg` rather than JSON fields,
`extract` it (pattern below assumes `METHOD PATH PROTO STATUS HOP RTs`):

## Queries

MCP `query` tool **requires `start`** (e.g. `"start":"1h"` or RFC3339) — omit it and the call fails with `start param is required`. With curl, `_time:` in the query is enough.

Always give a time filter, keep windows tight.

```logsql
# status mix customers saw
_time:1h source:nginx_access hop:front
  | extract "<method> <path> <proto> <status> <hop2> <rt>s"
  | stats by (status) count() n | sort by (n desc)

# top 5xx that reached PHP
_time:1h source:nginx_access hop:backend
  | extract "<method> <path> <proto> <status> <hop2> <rt>s"
  | filter status:>=500 | stats by (path) count() n | sort by (n desc) | limit 10

# slow backend requests (rt in seconds)
_time:1h source:nginx_access hop:backend
  | extract "<method> <path> <proto> <status> <hop2> <rt>s"
  | filter rt:>2 | sort by (rt desc) | limit 20 | fields _time, path, status, rt

# Magento log volume by file + level
_time:24h source:magento
  | extract_regexp "main\\.(?P<level>[A-Z]+):"
  | stats by (file, level) count() n | sort by (n desc)

# everything around a Bugsink event (timestamp ±2m)
_time:[<t-2m>, <t+2m>] -source:nginx_access
```

## How to use it in the HCF loop

- **Investigating a uat/live symptom:** Bugsink Query 1 first, then status
  mix / 5xx / slow on the matching env server. Cite the LogsQL query + rows.
- **pre-plan on a hot area:** 5xx + slow filtered to the area's URL prefix
  (`| filter path:~"^/checkout"`) on `logs-prod`.
- **post-deploy verify (uat):** status mix + app-log CRITICAL count since the
  deploy on `logs-uat`, against the same window before it.
- Traffic counts here are real prod numbers — prefer them over the dev DB for
  scale questions, and still defer behaviour-changing decisions to the owner.
