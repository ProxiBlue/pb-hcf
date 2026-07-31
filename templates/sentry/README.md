# magento2-sentry template — per-project install for pb-hcf's `issue-sentinel` agent

`justbetter/magento2-sentry` is the Sentry-SDK-compatible Magento module that reports runtime
errors into the central Bugsink instance (see `services/bugsink/README.md`) so pb-hcf's
`issue-sentinel` agent has something to query. Install this once per Magento ddev project.

## Install

```bash
composer require justbetter/magento2-sentry
bin/magento module:enable JustBetter_Sentry
bin/magento setup:upgrade
```

Register the project's Bugsink DSN first if you haven't (see `services/bugsink/README.md` →
"Add a project") — you need it for the `env.php` config below.

## Configure via `env.php`

Add (or merge into) `app/etc/env.php`:

```php
'sentry' => [
    'active' => true,
    'dsn' => getenv('SENTRY_DSN'),
    'environment' => 'ddev',
    'release' => getenv('HCF_RELEASE') ?: null,
    'traces_sample_rate' => 0.0,
],
```

Key wiring, one per line:

- **`dsn`** — never hardcode the DSN value in `env.php` (it would then be committed with the
  project). Source it from the env var `SENTRY_DSN`, which you export in the ddev container's
  `.ddev/config.yaml` `web_environment` (or `.ddev/.env`) from the registry entry
  `BUGSINK_DSN_<PROJECT>` in `~/.pb-hcf/bugsink.env` on the host — DSN values live in that file
  only (mode 600, not in git), never in any file this template touches.
- **`environment`** — literal `ddev` for every ddev-hosted project instance. This is what lets
  Bugsink (and a human skimming the issue list) distinguish local/dev noise from a real
  production DSN, should the same project ever also report from a non-ddev environment.
- **`release`** — read from the `HCF_RELEASE` env var (see `docs/release-tagging.md`), which the
  plan-orchestrate wrapper exports as `<plan-name>#<batch-n>` for the duration of a batch. This is
  the field `issue-sentinel` filters its Bugsink query on, so every error event ingested during a
  batch is attributable back to the plan/batch that produced it. If `HCF_RELEASE` is unset (e.g.
  you're poking around manually, outside an orchestrated run), leave `release` `null` — Sentry SDKs
  tolerate a missing release; `issue-sentinel` falls back to filtering by git short SHA + its own
  batch-start marker in that case, per the documented fallback.

Export `SENTRY_DSN` in the ddev environment (host side, not committed):

```bash
# .ddev/config.yaml
web_environment:
  - SENTRY_DSN=${BUGSINK_DSN_<PROJECT>}   # sourced from ~/.pb-hcf/bugsink.env at ddev start
```

`env var names only in this template — no secret values`.

## Verify

```bash
bin/magento sentry:test   # module-provided smoke command, if shipped; else trigger a real error and check Bugsink
```

Or fire a one-off event directly and confirm it lands, without waiting for a real Magento error:

```bash
source ~/.pb-hcf/bugsink.env
curl -sS -H "Authorization: Bearer $BUGSINK_API_TOKEN" \
  "$BUGSINK_URL_CONTAINER/api/canonical/0/issues/?project=<id>" | jq '.[] | select(.release == "'"$HCF_RELEASE"'")'
```

An empty result is expected on a fresh install (no errors yet) — the check confirms the API call
itself succeeds (HTTP 200, not connection-refused) and that the project id / token are correct.
To confirm ingestion end-to-end, trigger a deliberate test error in the storefront/admin and
re-run the curl — it should appear with `release` matching the current `HCF_RELEASE` (or the
git-SHA fallback, per `docs/release-tagging.md`).

## Consumed by

`agents/issue-sentinel.md` queries this project's Bugsink issues, filtered by `first_seen` since
its rolling batch-start marker and by the `release` this module tags every event with. See that
agent's source for the full query + triage flow.
