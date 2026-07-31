# Project Constitution

Immutable project invariants. This file is installed once by `/pb-hcf:wire` (copied from
`pb-hcf/templates/constitution.md` to `.claude/constitution.md`, never overwritten once
present) and then copied — unmodified — into every plan directory as `_constitution.md` by
`pre-implementation-incident-recall`. Every tdd-worker and reviewer that reads the plan
directory therefore carries these invariants without re-deriving them per task.

Fill in the placeholders below with this project's actual rules. Sections left as
`<!-- TODO: fill in -->` are treated as "not yet defined" by consuming agents — they do not
block, but they also don't supply guidance.

## Never-edit vendor / core

<!-- TODO: fill in -->

List the paths / packages that must never be hand-edited (vendor/, core Magento modules,
generated code, third-party composer packages). State the correct alternative (plugin,
preference, observer, patch via composer) for each.

## Branch rules

<!-- TODO: fill in -->

- **Protected branches** (LIVE-equivalent, never commit to directly): e.g. `live`, `uat`, `main`, `master`.
- **Feature branch naming convention**: e.g. `feature/<ticket>-<short-desc>`.
- **Squash-merge rules**: how feature branches land (squash vs merge commit, who merges, PR required?).
- **Deploy commit format**: the exact commit message / tag convention used to trigger deploy.

## Vendor blocklist

<!-- TODO: fill in -->

Pointer to the authoritative vendor-verdict source rather than a static list (verdicts change
over time and are better tracked with provenance):

```
mcp__graphiti__search_memory_facts(group_ids=["<project-id>", "fleet"], query="<vendor/module name> verdict")
```

Any agent evaluating a vendor module or extension MUST query graphiti with the module/vendor
name before recommending it. A blocked verdict found this way is binding.

## Verification checklist

<!-- TODO: fill in -->

Reference the project's upgrade-verification checklist (spec files to run, admin flows to
exercise, golden-path coverage) rather than duplicating it here. E.g.:

- Upgrade / update / new-module changes: see `~/claude-skills-central/rules/upgrade-verification.md`
  (admin checkout, custom-module regression specs, frontend golden path — enumerate + run, never
  claim coverage for a spec not executed).
- Project-specific spec directories: `<path/to/e2e/specs>`.

## Testing scope rules

<!-- TODO: fill in -->

State this project's test-command scoping (targeted vs full-suite; see the "test deferral" note
in the HCF plan-orchestrate rule for why full-suite-per-task can collide under parallel workers).
