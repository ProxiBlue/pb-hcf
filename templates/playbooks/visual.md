# visual — frontend visual-regression ground truth

**Authority scope:** visual correctness. When a change touches theme, layout,
Tailwind, templates (`.phtml`), or anything that renders, this playbook says how
to prove the page still *looks* right — not merely that it functions.

The project's Playwright suite (`tests/m2-hyva-playwright`) carries full-page
snapshot baselines; the committed pngs in `*.spec.ts-snapshots/` dirs ARE the
design ground truth (multi-browser × multi-viewport). Typical coverage: header
(`theme.spec.ts`), cart (`cart-table-structure.spec.ts`), golden-path pages
(`visual-golden-path.spec.ts` — home, PLP, PDP).

## The rule (build loop)

1. **Frontend diff ⇒ run the visual specs** before calling the work done:
   ```bash
   cd tests/m2-hyva-playwright/src/apps/pps && \
   APP_NAME=pps TEST_BASE=pps npx playwright test visual-golden-path theme cart-table-structure --workers=2
   ```
2. **On failure, READ the diff images** (`test-results/.../*-diff.png`) with the
   Read tool and say what actually changed — "menu dropped 12px at md-768" is a
   finding; "screenshot mismatch" is not.
3. **Classify, then act:**
   - **Unintended** → it's a regression; fix the code, not the baseline.
   - **Intended** (the change is *supposed* to alter the look) → regenerate
     deliberately and commit the new pngs WITH the change:
     ```bash
     npx playwright test <specs> --update-snapshots
     ```
4. **NEVER blind-update baselines to turn red green.** Updating a baseline is a
   design decision — it must be named in the commit message ("baselines: new
   PDP gallery layout"), and belongs to the same commit/branch as the code that
   changed the look. An update with no corresponding intentional design change
   is laundering a regression; stop and flag instead.

## Baseline lineage

Baselines must be captured from the branch that is the incoming production
truth (e.g. seeded from `loki` pre-go-live, 2026-08-03). After a redesign lands
on the mainline, re-seed on top of it — stale-lineage baselines make every
honest run red and train people to ignore the suite.

## Design references (when they exist)

A ticket carrying a design spec (Figma export, mockup image) outranks the
baseline: compare the rendered page to the *spec* first (screenshot + eyeball
via the Read tool), then update baselines to match the approved result. No
spec on the ticket → the baseline is the spec.
