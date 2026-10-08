# sentry-python template — per-project install for pb-hcf's `issue-sentinel` agent (Python / FastAPI)

Python-stack sibling of `templates/sentry/README.md` (Magento). `sentry-sdk` reports runtime errors
into the central Bugsink instance (Sentry-compatible — see `services/bugsink/README.md`) so
pb-hcf's `issue-sentinel` agent has something to query. Install once per Python project.

## Bugsink DSN contract — one Bugsink project per environment

- Each **environment** (dev / uat / prod) of the app gets its **own Bugsink project** and therefore
  its own DSN. Never point dev and prod at the same project: the project id is the separation
  boundary — a wrong id silently answers the wrong question for `issue-sentinel` and for humans
  reading the issue list.
- DSN values live only in `~/.pb-hcf/bugsink.env` on the host (mode 600, not in git) as
  `BUGSINK_DSN_<PROJECT>` (dev) / `BUGSINK_DSN_<PROJECT>_PROD` etc., and in the production host's
  own secret store. Never in any committed file, never in this template.
- The app reads it from `<PREFIX>_SENTRY_DSN` (`<PREFIX>` = the app's settings env prefix, e.g.
  `PDF2VEC_SENTRY_DSN`). Unset/empty DSN → SDK not initialised → app runs normally with no
  reporting (safe default for tests and CI).

## Install

```bash
uv add "sentry-sdk[fastapi]"        # or: pip install "sentry-sdk[fastapi]"
```

## Init snippet

Call as early as possible — before the `FastAPI()` app object is created (e.g. top of
`app/main.py`, or inside the app factory before `FastAPI(...)`).

```python
# app/observability.py
import sentry_sdk
from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class SentrySettings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="<PREFIX>_", extra="ignore")

    sentry_dsn: SecretStr | None = None      # <PREFIX>_SENTRY_DSN
    environment: str = "dev"                 # <PREFIX>_ENVIRONMENT: dev | uat | prod
    release: str | None = None               # <PREFIX>_RELEASE (falls back to HCF_RELEASE below)


def init_sentry() -> None:
    import os

    s = SentrySettings()
    if s.sentry_dsn is None or not s.sentry_dsn.get_secret_value():
        return
    sentry_sdk.init(
        dsn=s.sentry_dsn.get_secret_value(),
        environment=s.environment,                      # tag: lets Bugsink/humans tell dev noise from prod
        release=s.release or os.getenv("HCF_RELEASE"),  # issue-sentinel filters on this
        traces_sample_rate=0.0,                         # errors only — no tracing load on Bugsink
        send_default_pii=False,                         # no headers/IPs/user data in events
    )
```

```python
# app/main.py
from app.observability import init_sentry

init_sentry()
app = FastAPI()
```

The FastAPI + Starlette integrations auto-enable when `fastapi` is installed. Default
`transaction_style="url"` names events by route template (`/invoices/{invoice_id}`) — that is what
the `bugsink.md` playbook's `transaction` filter expects; keep it. Default
`failed_request_status_codes` = 5xx only, which is right for issue-sentinel (4xx are client errors,
not regressions).

Key wiring, one per line:

- **`dsn`** — from `<PREFIX>_SENTRY_DSN` via `SecretStr`; never logged, never hard-coded.
- **`environment`** — `dev` for local/ddev, `prod` on live. Must match the Bugsink project the DSN
  belongs to (one project per environment, above).
- **`release`** — `HCF_RELEASE` (`<plan-name>#<batch-n>`, exported by plan-orchestrate — see
  `docs/release-tagging.md`) during orchestrated runs; the deploy's git SHA in production. Unset
  is tolerated; issue-sentinel falls back to SHA + its batch-start marker.
- **`traces_sample_rate=0`** and **`send_default_pii=False`** — fixed; change only with an explicit
  decision recorded in the project's constitution.

## Verify

```bash
<PREFIX>_SENTRY_DSN="$BUGSINK_DSN_<PROJECT>" python -c \
  'from app.observability import init_sentry; init_sentry(); 1/0'
source ~/.pb-hcf/bugsink.env
curl -sS -H "Authorization: Bearer $BUGSINK_API_TOKEN" \
  "$BUGSINK_URL_HOST/api/canonical/0/issues/?project=<id>" | jq -r '.results[] | [.friendly_id, .calculated_type] | @tsv'
```

The `ZeroDivisionError` must appear within seconds. (`$BUGSINK_URL_CONTAINER` inside a ddev container.)

## Consumed by

`agents/issue-sentinel.md` (post-batch Bugsink query, filtered by `first_seen` + `release`) and the
`bugsink.md` playbook (plan-time read).
