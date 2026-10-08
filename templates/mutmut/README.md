# mutmut template — per-project install for pb-hcf's `mutation-tester` agent (Python)

Python-stack sibling of `templates/infection/README.md`. `mutation-tester` detects mutmut at
`.venv/bin/mutmut` or via `uv run mutmut`, runs it only on the plan's changed source modules, and
gates on kill rate (MSI-equivalent). Without mutmut installed the agent returns
`STATUS: PASS-with-note` — never a block.

## Install

```bash
uv add --dev mutmut          # or: .venv/bin/pip install mutmut
```

## `pyproject.toml`

mutmut ≥ 3.6 key names:

```toml
[tool.mutmut]
source_paths = ["src/"]                               # what may be mutated
pytest_add_cli_args_test_selection = ["tests/"]       # which tests run against each mutant
do_not_mutate = ["*/migrations/*", "*/scripts/*"]     # never mutate these
```

Older mutmut releases use the original names for the same settings — `paths_to_mutate`,
`tests_dir`, and (mutmut 2.x only) `runner`:

```toml
[tool.mutmut]
paths_to_mutate = ["src/"]
tests_dir = ["tests/"]
runner = "python -m pytest -x -q"      # mutmut 2.x; 3.x always drives pytest itself
```

Use whichever matches the installed version (`mutmut --version`). Keep the test run fast and
fail-first (`-x`): mutmut re-runs tests once per mutant.

## Project overrides read by `mutation-tester` (`.claude/testing.md`)

```
mutation_paths: src/**/*.py
mutation_min_msi: 60
mutation_min_covered_msi: 75
```

All optional; the values above are the defaults (same floors as the Infection template). Raise
floors per project; never lower them silently.

## How the agent runs it

1. Changed `*.py` under `mutation_paths` since the plan baseline, minus `tests/`, `conftest.py`,
   `scripts/`, migrations.
2. `mutmut run "<module>*"` per changed module (`src/app/billing/invoice.py` → `app.billing.invoice*`).
3. `mutmut results --all` (authoritative, filtered to scoped modules) +
   `mutmut export-cicd-stats` (`mutants/mutmut-cicd-stats.json`) as a cross-check.
4. Kill rate = (killed + timeout) / (killed + timeout + survived + suspicious + no_tests);
   covered kill rate drops `no_tests` from the denominator.
5. PASS / PUSHBACK with every survivor cited as `file:line — mutant: <name>` (from `mutmut show`).

Add `mutants/` to `.gitignore`.

## Runtime cost

Same caveat as Infection: once per plan, never per task. A plan touching a hot module with a slow
suite can take minutes — keep `pytest_add_cli_args_test_selection` narrow.
