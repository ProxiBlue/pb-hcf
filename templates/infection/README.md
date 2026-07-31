# Infection mutation-testing template — for pb-hcf's `mutation-tester` agent

Install into a project:

```bash
composer require --dev infection/infection
cp infection.json5.dist <project>/infection.json5
```

Adjust `app/code/<Vendor>` to your project's actual custom-module namespace(s) (add more entries to
`source.directories` for multiple vendors) and `phpUnit.configDir` to point at your project's real
`phpunit.xml.dist` location. See the template's inline comments for what each non-obvious setting
(`timeout`, `minMsi`, `minCoveredMsi`, the three `logs` paths) is for.

## Running (scoped to a plan's changed files only)

Never run Infection unscoped against the whole `app/code/` tree — always filter to the files a plan
actually touched:

```bash
vendor/bin/infection \
  --filter="$(git diff --name-only "$BASELINE_REF"..HEAD -- 'app/code/**/*.php' | tr '\n' ',')" \
  --min-msi=60 --min-covered-msi=75 \
  --logger-json=var/infection/infection.json
```

`$BASELINE_REF` is the plan's starting commit — the same changed-files convention pb-hcf uses for
`rector-enforcement-wiring` and `modernization-sweep-skill` (changed `*.php` under `app/code/`,
excluding `generated/`, `vendor/`, and test fixtures).

## Runtime-cost caveat

Infection re-runs the **full PHPUnit suite once per generated mutant**. Even scoped to a handful of
changed files this can take minutes on a Magento bootstrap, and unscoped runs against the whole
`app/code/` tree are impractical (hours). The `--filter` scoping above is mandatory, not optional.

## Run once per plan, not per batch

pb-hcf's `mutation-tester` agent enrolls at `post-implementation`, `mode: single` — it fires once,
after ALL of a plan's tasks have landed and the diff is final, not per-task or per-batch. Re-running
mutation testing on every batch multiplies the cost above for no additional signal until the diff
stabilizes; leave it at the single end-of-plan gate.

## Graceful degrade

If `infection/infection` is not composer-installed, the `mutation-tester` agent does **not** block the
plan — it returns `STATUS: PASS-with-note` instructing this install command and records the gap in the
plan dir's `_mutation_tester.md` so the skip is visible, not silent.
