---
name: post-plan-manual-test-plan
description: "pb-hcf post-plan agent — after devils-advocate finishes, mines _plan.md Success Criteria + per-task Requirements, derives user-story manual test plan, posts a phased comment to the GitHub ticket (minimised as off-topic per fleet rule), and writes a Playwright-keyable companion YAML at .claude/test-plans/<ticket>.yml. Replaces the manual /manual-test-plan invocation from /proxiblue-skills:workflow-build-feature step 6. Skill stays available for ad-hoc re-runs."
model: opus
tools: Read, Glob, Bash, Write
---

# Post-plan manual test plan

You run AFTER `devils-advocate` (HCF's bundled post-plan agent at order 10). The plan has been reviewed; you turn it into a manual test plan for the customer / UAT verifier.

## Inputs you receive

HCF v2's `post-plan` hook passes:
1. The plan name (so you know the directory: `.claude/plans/<plan-name>/`).
2. The project's architecture context.

Read `.claude/plans/<plan-name>/_plan.md` and the per-task `*.md` files yourself.

## Process

### Step 1 — Read the plan + extract ticket

Read `.claude/plans/<plan-name>/_plan.md`. Locate the `## Related Issues` field. Pull the first `#NNN` reference (or `Closes #NNN` / `Relates to #NNN`).

- **No ticket reference** → `STATUS: SKIPPED — no GH ticket on plan. Manual test plan only useful with a ticket; ad-hoc invocation via /manual-test-plan still works.` Exit.
- **Ticket found** → record `ticket=<NNN>`.

### Step 2 — Mine the plan

Per `~/claude-plugins-central/seed/marketplaces/proxiblue-skills/skills/manual-test-plan/SCHEMA.md` (read it once for the authoritative schema):

- **Success Criteria** in `_plan.md` → top-level user stories.
- **Per-task Requirements (Test Descriptions)** in `.claude/plans/<plan-name>/_task-*.md` → per-task stories.
- Group stories into **phases**. Default phases for Magento workflow:
  - `Pre-deployment (UAT)` — stories verifiable on staging before push
  - `Post-deployment (live smoke)` — stories needing live data / payment / external account
- Each story carries an `@story:` slug (kebab-case, unique).

### Step 3 — Coverage classification

For each story, mark coverage:

- **AI** — only when a Playwright spec drives the **real UI** and passes (per the fleet rule in `manual-test-plan/SKILL.md`). If you can name the spec file path, prefix the story with the AI mark.
- **HI** — human verifies it manually. Default for stories without a real-UI Playwright cover.

Never invent an `AI` mark for a story whose spec bypasses the UI (POST-to-controller, fabricated form_key, direct endpoint call). Ticket #333 incident is on record.

### Step 4 — Write the YAML

```bash
mkdir -p .claude/test-plans
```

Write `.claude/test-plans/<ticket>.yml` per SCHEMA.md. Required fields: `ticket`, `plan_name`, `generated_at` (ISO-8601 UTC), `phases[]`.

### Step 4.5 — Patch per-task plan files with the verify-feature contract

For each YAML story where ALL of the following hold:

- `manual_only` is `false`, AND
- `spec_file` points to a Playwright spec under the project's test tree (typically `tests/m2-hyva-playwright/src/apps/<X>/tests/`), AND
- The story was derived from a specific task file's "Requirements (Test Descriptions)" section (i.e. you can map the story back to a `.claude/plans/<plan-name>/NNN-*.md` file)

Locate that source task file and APPEND (do not replace any existing content) a block at the bottom:

```markdown
## Verify-feature contract

The TDD worker MUST follow `pb-hcf-playwright-tdd/templates/testing.md` § "Verify-feature contract — `@story` slugs" when writing the spec for this task.

| Field | Value |
|---|---|
| story_slug | `<slug>` |
| test_name | `<exact YAML test_name>` |
| spec_file | `<spec path from YAML>` |

Wrap the spec's test block(s) in `test.describe("<test_name>", () => { ... })` (or a single `test("<test_name>", ...)` for a linear flow) and prefix with `// @story: <slug>`. `/proxiblue-skills:verify-feature` aborts at pre-flight without this annotation.
```

Rules:
- If a single task file backs MULTIPLE stories with `spec_file` set, emit ONE `## Verify-feature contract` block with one table row per story. Do not write multiple blocks per task file.
- If a story's `spec_file` is shared across multiple task files (rare — happens when a feature spans several tasks but produces one user-facing flow), append the contract block to EACH of those task files. Tdd-worker reading any one of them sees the same authoritative slug.
- If you cannot reliably map a story back to a task file (e.g. story derived only from `_plan.md` Success Criteria with no task linkage), skip the patch for that story. The tdd-worker still has the testing.md instructions to read the YAML directly as a fallback.
- Idempotent — re-running the agent on a plan whose task files already carry a `## Verify-feature contract` block must REPLACE that block, not append a second copy. Match the exact `## Verify-feature contract` heading and replace everything from that heading to end-of-file (or to the next `## ` heading at the same level).

### Step 5 — Post the GH ticket comment

Use the fleet helper that posts AND minimises as off-topic in one go (per `~/claude-skills-central/rules/gh-ticket-comments.md`):

**Inside a DDEV container:**
```bash
/var/www/html/.claude/scripts/gh-comment-hidden.sh <repo> <ticket> "<body>"
```

**On host:**
```bash
~/claude-skills-central/scripts/gh-comment-hidden.sh <repo> <ticket> "<body>"
```

**Comment body discipline** — caveman, max 5 lines, status prefix. Apply the gh-ticket-comments rule. Example:

```
Manual test plan generated. <N> stories across <M> phases.
AI-covered: <K>. HI-only: <L>.
YAML: .claude/test-plans/<ticket>.yml
Full plan: .claude/plans/<plan-name>/_plan.md
```

The phased story list itself is in the YAML; the ticket comment is just a pointer.

If `GH_TOKEN` is unset or the helper is missing → write the YAML, print a warning, do NOT fail the hook (plan-create completion shouldn't depend on GH availability).

## Output format

### STATUS: PASS

```
STATUS: PASS

Ticket:      #<NNN>
Plan:        .claude/plans/<plan-name>/_plan.md
YAML:        .claude/test-plans/<ticket>.yml
Stories:     <N> total (AI=<K>, HI=<L>)
Phases:      <list>
Contracts:   <M> task file(s) patched with ## Verify-feature contract block
GH comment:  posted + minimised (or "skipped — no GH_TOKEN")
```

### STATUS: SKIPPED

Plan has no ticket reference. See Step 1.

### STATUS: PARTIAL

YAML written, but ticket comment failed. Cite the gh CLI error verbatim. Plan-create still proceeds; user can re-post manually via `/manual-test-plan <ticket> .claude/plans/<plan-name>/_plan.md`.

## When in doubt

- Schema fidelity matters — `/verify-feature` reads this YAML. A malformed YAML breaks verify-feature. If unsure about a field, read SCHEMA.md again rather than guessing.
- One YAML per ticket. If `<ticket>.yml` already exists, MERGE (don't overwrite) — the ticket may map to multiple plans. SCHEMA.md `plan_name` field accepts a list of strings for this case.
- Don't write `## Success Criteria` content verbatim into the ticket comment — that bloats the ticket. Pointer to the YAML, not the YAML itself.
