---
name: wire
description: Wire HCF agents (devils-advocate, tdd-worker, standards-enforcer, plus pb-hcf's gitnexus-reviewer + security-quorum agents) into the fleet's per-domain playbooks (gitnexus, graphiti, security, …) by installing playbook files into .claude/<name>.md, appending a single fenced section to .claude/CLAUDE.md, optionally enrolling pb-hcf agents into HCF v2 hook frontmatter (--enable=<name>[,<name>]), and recording wire state in .claude/wires.json. Multi-playbook successor to the per-plugin wire skills (replaces /pb-gitnexus:wire). Run AFTER /hcf:project-setup.
model: sonnet
disable-model-invocation: true
---

# /pb-hcf:wire

Install pb-hcf's fleet playbooks into the current project so HCF's existing agents (devils-advocate, tdd-worker, standards-enforcer) and pb-hcf's bundled agents (`gitnexus-reviewer`, `security-quorum`) pick up the per-domain guidance via context. This is the consolidated replacement for `/pb-gitnexus:wire` — one skill installs ALL playbooks under `pb-hcf/templates/playbooks/` instead of one skill per plugin.

**Architectural note (HCF v2.0.0+):** HCF dropped `.claude/pipeline.md`. Agents now enroll into the 8 hook points (`pre-plan`, `post-plan`, `pre-implementation`, `pre-batch`, `post-batch`, `post-implementation`, `pre-commit`, `post-commit`) via YAML frontmatter (`phase:` / `order:` / `mode:`). See `${CLAUDE_PLUGIN_ROOT}/../hcf/HOOKS.md` (or `https://github.com/markshust/hcf#pipeline`).

**Architectural note (RO-mount-respecting fleet design):** Most projects in the ProxiBlue fleet mount `~/claude-code-magento-agents/` RO at `/var/www/html/.claude/agents/` — by design, so containerized agents can't modify gatekept config. HCF's discovery globs `.claude/agents/*.md` inside the container, which means agent files MUST live in the mount source (`~/claude-code-magento-agents/`), not in project-local `.claude/agents/` (which the mount shadows). This skill's `--enable` flow auto-detects the mount source from the project's `.ddev/docker-compose*.yaml` and writes there. Projects without that mount fall back to project-local `.claude/agents/`. All writes happen from the host shell so the RO-mount intent is preserved (container view stays read-only).

This skill:
- Installs project-local playbook docs at `.claude/<name>.md` referenced from a fenced section in `.claude/CLAUDE.md` (consulted via context by HCF's bundled agents — no agent-dir write needed for the playbook layer; `.claude/` itself is project-RW).
- **Optionally** enrolls pb-hcf bundled agents into HCF's hook pipeline by copying them — with appropriate frontmatter stamped — to the resolved enrollment target directory (`~/claude-code-magento-agents/` for fleet-mounted projects, `.claude/agents/` for the fallback). Only when the user passes `--enable=<name>[,<name>]` (or `--enable-all`). Default is off (the plugin agents stay dormant in plugin source). Idempotent: re-runs skip silently if an agent is already enrolled with the expected `phase`.
- **Refuses to run while a legacy `.claude/pipeline.md` is present** — HCF gates `plan-create` / `plan-orchestrate` until it is migrated via `/hcf:project-update`. Tell the user, stop, do not write anything.

## Prerequisites Check

Abort with a clear message if any fail:

1. **Run from project root** — current working directory contains a recognisable project marker (`composer.json`, `package.json`, `pyproject.toml`, `.git/`).
2. **HCF project-setup has run** — `.claude/CLAUDE.md` must exist (created by `/hcf:project-setup`). If absent, tell user to run `/hcf:project-setup` first and stop.
3. **Plugin install path resolvable** — `$CLAUDE_PLUGIN_ROOT/templates/playbooks/` must be readable and contain at least one `*.md` file. If empty, this install is corrupt — tell user to `/plugin reinstall pb-hcf`.
4. **No legacy `.claude/pipeline.md`** — if present, halt immediately. Tell the user:
   > HCF v2.0.0 retired `.claude/pipeline.md`. While it exists, HCF blocks `plan-create` and `plan-orchestrate`. Run `/hcf:project-update` first — it migrates any active entries into per-agent frontmatter (`.claude/agents/<name>.md` with `phase:` stamped) and removes the file — then re-run `/pb-hcf:wire`.

   Do NOT touch `pipeline.md` from this skill. Migration is HCF's job; this skill only wires once the migration is done.

## Playbook discovery

Enumerate all `*.md` files under `$CLAUDE_PLUGIN_ROOT/templates/playbooks/`. Each file becomes one wire entry. The basename (sans `.md`) is the playbook name (e.g. `gitnexus.md` → `gitnexus`).

For each playbook, read its first heading (`# <Title>`) — used in the CLAUDE.md fenced section pointers.

## Per-playbook reachability probes (best-effort, non-fatal warnings)

For each discovered playbook, attempt a domain-appropriate reachability probe and record the result in `.claude/wires.json`. Failed probes do NOT block the wire — the docs are useful even before services are up.

| Playbook | Probe | Expected |
|---|---|---|
| `gitnexus.md` | `curl -sS -o /dev/null -w '%{http_code}\n' -m 3 http://gitnexus:4747/` then `mcp__gitnexus-mageos__list_repos` | HTTP 200 + non-empty repo list |
| `graphiti.md` | `mcp__graphiti__get_status` (URL detected from env — host or `host.docker.internal`) | `status: ok` |
| `security.md` | No standalone probe — quorum agents reachable as long as `gitnexus` + `graphiti` are. Mark `reachable: true` unconditionally; record dependency on the other two playbooks' state in `details`. | n/a |
| `playwright.md` | (future — define when shipping) | TBD |
| Any other | Skip probe; mark `reachable: unknown` | — |

Record per-playbook probe result in `.claude/wires.json`. Unknown / unreachable probes get a warning in the completion output with the recommended fix command.

## Actions

### 1. Install each playbook

For each `<name>.md` under `templates/playbooks/`, copy verbatim to `.claude/<name>.md` (no template substitutions — playbooks are project-agnostic; agents resolve project-specific values like `$DDEV_PROJECT` at use time).

- If destination exists and differs → show diff, confirm overwrite (default yes unless `--no-overwrite` passed).
- If destination exists and is identical → skip silently.

### 2. Update the single fenced section in `.claude/CLAUDE.md`

Use ONE fenced section with stable markers, listing pointers to ALL installed playbooks:

```markdown
<!-- pb-hcf:start -->
## Per-domain Playbooks (pb-hcf wires)

For domain-specific tooling and per-agent playbooks, consult the relevant file:

- **Code-graph queries** (callers, dependents, signatures, Magento wiring) → `@.claude/gitnexus.md`
- **Knowledge graph** (discussions, decisions, planned features, prior incidents) → `@.claude/graphiti.md`
- **Security audit** (OWASP, vulnerability assessment) → `@.claude/security.md`
- **End-to-end testing** (Playwright + coverage) → `@.claude/playwright.md`

Each playbook declares its **Authority scope** at the top — defer to the named playbook when a question falls in its scope; cross-cite when a question spans two.
<!-- pb-hcf:end -->
```

Only emit pointer lines for playbooks that actually got installed in step 1. Re-runs replace the entire fenced section (not duplicate, not split).

### 3. Detect + replace legacy `pb-gitnexus:` fence (migration)

If `.claude/CLAUDE.md` contains a legacy `<!-- pb-gitnexus:start --> ... <!-- pb-gitnexus:end -->` block from the deprecated wire, remove it before writing the new `pb-hcf:` fence (handled inline in step 2). Report this as `migrated legacy pb-gitnexus fence → pb-hcf fence` in the completion output. Also clean up `.claude/gitnexus.json` if present (renamed semantically — its data is now in `.claude/wires.json`).

### 4. Optional hook enrollment for pb-hcf bundled agents

pb-hcf ships 10 enrollable agents that together implement the **full** custom-workflow that `/proxiblue-skills:workflow-build-feature` used to orchestrate as a wrapper. Each agent enrolls at a specific HCF v2 hook so vanilla `/hcf:plan-create` + `/hcf:plan-orchestrate` execute the entire flow — no wrapping skill required.

| Agent | `phase` | `order` | `mode` | What it does |
|---|---|---|---|---|
| `pre-flight-check` | `pre-plan` | `5` | `single` | Verifies onboarding artifacts, loops `wires.json` probes, refuses to run on protected branches (`live` / `uat` / `main` / `master`). Replaces workflow-build-feature steps 1–3. |
| `pre-plan-graphiti-recall` | `pre-plan` | `10` | `single` | Searches Graphiti for the feature topic — prior decisions, incidents, vendor verdicts, planned-but-not-built. Returns Historical Context block. |
| `post-plan-manual-test-plan` | `post-plan` | `50` | `single` | After `devils-advocate` finishes, mines `_plan.md` + per-task Requirements, derives user stories, posts a phased GH ticket comment + writes `.claude/test-plans/<ticket>.yml` per SCHEMA. Replaces workflow-build-feature step 6. |
| `pre-implementation-incident-recall` | `pre-implementation` | `10` | `single` | Per-task Graphiti lookup of prior incidents in the touched area. PREPENDS findings to each `_task-NNN.md` so tdd-workers see them. |
| `gitnexus-reviewer` | `post-implementation` | `30` | `single` | Diff-impact review via GitNexus code graph (callers, plugins, observers, DI wiring). |
| `graphiti-reviewer` | `post-implementation` | `40` | `single` | Diff-vs-knowledge-graph review (prior decisions, incidents, vendor verdicts, planned work overlap). |
| `security-quorum` | `post-implementation` | `70` | `single` | 3-agent 2-of-3 security consensus (spawns its own trio: static-analyst, adversarial-tester, defensive-auditor). |
| `pre-commit-adversarial-pass` | `pre-commit` | `10` | `single` | One last adversarial-tester pass on the staged diff after tests pass, before commit. Returns PASS or DEFER (advisory; doesn't block commit). |
| `post-commit-verify-handoff` | `post-commit` | `10` | `single` | Prints the fresh-thread instruction for `/verify-feature` (skill convention). |
| `post-commit-build-summary` | `post-commit` | `20` | `single` | Prints the BUILD COMPLETE summary aggregating every hook's verdict + deferred concerns + ready-to-deploy guidance. Replaces workflow-build-feature step 13. |

(The 3 security specialists — `security-static-analyst`, `security-adversarial-tester`, `security-defensive-auditor` — are library agents spawned BY `security-quorum` at runtime. They do NOT declare a `phase` themselves and are NOT in the enrollable list.)

**Default: nothing is enrolled.** All 10 agents ship dormant in `$PLUGIN/agents/<name>.md` without `phase` — visible to `Task` but not auto-fired in the pipeline (mirrors how HCF ships `standards-enforcer` with its `phase` commented out).

### Target-directory resolution (host-side, fleet-aware)

Wire's `--enable` writes agent files to wherever HCF's discovery routine globs `.claude/agents/*.md` *from inside the container*. In the ProxiBlue ddev fleet that path is RO-mounted from a host-side central dir (`~/claude-code-magento-agents/`) — wire MUST write to the mount source, not the project-local `.claude/agents/` (which is shadowed by the mount and host-side root-owned). For projects without that mount, wire falls back to project-local `.claude/agents/`.

Detection order:

1. **`--target=<host-path>` flag** — explicit override. Use this exact directory.
2. **Parse the project's `.ddev/docker-compose*.yaml`** — look for a volume line whose target ends with `:/var/www/html/.claude/agents:ro` (or `:rw`). Extract the host-side source path (before the colon, with `$HOME` expanded). That's the target. Fleet pattern: `~/claude-code-magento-agents`.
3. **No mount found** — fall back to project-local `.claude/agents/` (writable host directory at project root).

In all three, the path must be **writable from host**. If not, abort with a clear message naming the path and the chown command to fix it.

**To enroll**: pass `--enable=<name>[,<name>]` (comma-separated). Example:
- `/pb-hcf:wire --enable=pre-flight-check,gitnexus-reviewer,security-quorum` — minimal sane set
- `/pb-hcf:wire --enable-all` — enroll **all 10** (full workflow-build-feature replacement)

For each enrolled name (let `TARGET` = resolved target directory per above):

1. **Idempotency check (skip-if-present-and-correct):**
   - If `$TARGET/<name>.md` **exists** AND its frontmatter declares `phase: <expected>` (matches the table above) → **skip silently** (`already enrolled — no action`).
   - If `$TARGET/<name>.md` **exists** with a **different `phase`** → leave it untouched, **warn** that the user has expressed a deliberate choice (e.g. they moved gitnexus-reviewer from `post-implementation` to `post-batch`). Do NOT overwrite.
   - If `$TARGET/<name>.md` **does not exist** → continue to step 2.
2. **Copy + stamp:**
   - Read the plugin's source agent at `$CLAUDE_PLUGIN_ROOT/agents/<name>.md` (this is the canonical body without `phase`).
   - Insert these three lines into its YAML frontmatter (immediately before the closing `---`):
     ```yaml
     phase: <from table>
     order: <from table>
     mode: <from table>
     ```
   - Write the result to `$TARGET/<name>.md`.
3. **Library agents (no phase):** `security-static-analyst`, `security-adversarial-tester`, `security-defensive-auditor` get copied to `$TARGET/<name>.md` **as-is** (no `phase` stamp) when `--enable=security-quorum` (or `--enable-all`) is passed. The quorum orchestrator spawns them via `Task` at runtime; they must exist somewhere the agent loader can find them.
4. **DO NOT touch `$TARGET/<name>.md` for any name not on the enrollable list.** The central dir may host unrelated content (e.g. the `~/claude-code-magento-agents/` library subdirs); wire MUST leave that alone.

**The enrolling action is fleet-wide when the target is a shared central dir.** All projects that mount the same source will see the same enrolled agents. Per-project granularity is achieved at the mount layer (which projects mount it), not at the wire layer. If you want a single project to differ from the fleet, use a project-specific target via `--target=<host-path>` AND change that project's mount to point at the project-specific dir.

**To disable a previously-enrolled agent**: delete `$TARGET/<name>.md` (or remove the `phase` key from its frontmatter). HCF's discovery routine reads frontmatter directly; no other state needs updating. Container picks up the change on next plugin discovery (typically next claude-code session).

**Recommended enrollment sets:**

| Scenario | Recommended `--enable` |
|---|---|
| Magento project, full custom workflow (replaces workflow-build-feature) | `--enable-all` |
| Magento project, no auto-test-plan posting | `--enable-all` then `rm $TARGET/post-plan-manual-test-plan.md` |
| Non-Magento project, graphiti recall only | `--enable=pre-plan-graphiti-recall,graphiti-reviewer,pre-implementation-incident-recall` |
| Security-focused only | `--enable=pre-flight-check,security-quorum,pre-commit-adversarial-pass` |
| Minimal (just structural review) | `--enable=gitnexus-reviewer` |

### 5. Write `.claude/wires.json` registry

```json
{
  "wiredAt": "<ISO timestamp>",
  "pluginVersion": "<from $CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json>",
  "playbooks": [
    {
      "name": "gitnexus",
      "file": ".claude/gitnexus.md",
      "probe": "http://gitnexus:4747/",
      "reachable": true,
      "details": { "repos": ["mageos", "hyva", "deps"] }
    },
    {
      "name": "graphiti",
      "file": ".claude/graphiti.md",
      "probe": "mcp__graphiti__get_status",
      "reachable": true,
      "details": { "neo4jConnected": true }
    }
  ],
  "enrollmentTarget": "/home/lucas/claude-code-magento-agents",
  "enrollmentTargetSource": "ddev-mount",
  "enrollments": [
    {
      "name": "gitnexus-reviewer",
      "file": "/home/lucas/claude-code-magento-agents/gitnexus-reviewer.md",
      "phase": "post-implementation",
      "order": 30,
      "mode": "single",
      "source": "pb-hcf"
    }
  ]
}
```

`enrollmentTarget` is the resolved host-side path agents land in. `enrollmentTargetSource` is one of `"flag"` (`--target` passed), `"ddev-mount"` (detected from docker-compose), or `"project-local"` (fallback to `.claude/agents/`).

`enrollments[]` is populated by scanning every `.md` file in `enrollmentTarget` for `phase:` in frontmatter — this catches both pb-hcf-stamped agents and any other locally-enrolled agents (e.g. an uncommented `standards-enforcer`). `source` is `"pb-hcf"` when the agent name matches a pb-hcf bundled agent, else `"local"`. The recorded `file` is an **absolute host path** since the target may be outside the project root in fleet-shared deployments.

This file is the **wire registry** — downstream skills like `/proxiblue-skills:workflow-build-feature` pre-flight, and CI checks, can read it to verify everything's still up before kicking off a long run. Updated every wire / re-wire / re-probe.

### 6. Report what changed

List each created / modified / removed file with a one-line summary. Include reachability state per playbook, the recommended fix for any that probed as unreachable, and the current `enrollments[]` set (or "none — pass --enable=… to activate").

## Idempotency

- Re-running is safe. Fenced section replaces, not duplicates. `wires.json` is rewritten with fresh timestamp + current probe + enrollment state.
- For overwritten playbook files, show the diff and confirm unless `--no-overwrite` is passed.
- For enrollment files (`$TARGET/<name>.md`): re-running `--enable=<name>` on an already-enrolled agent at the same `phase` is a no-op (silent skip); on a different `phase` it warns and refuses to overwrite.
- Flags:
  - `--reprobe` → re-run only the reachability probes, update `wires.json`, don't touch playbook files, CLAUDE.md, or the enrollment target.
  - `--no-overwrite` → skip diff prompts; leave existing playbook files untouched if they differ.
  - `--migrate-only` → only run the legacy `pb-gitnexus:` fence migration step (step 3), don't install or probe anything.
  - `--enable=<name>[,<name>]` → enroll the named pb-hcf bundled agent(s) into HCF's hook pipeline (see step 4 for full semantics and target-directory resolution).
  - `--enable-all` → shorthand for enrolling all 10 enrollable agents: `pre-flight-check,pre-plan-graphiti-recall,post-plan-manual-test-plan,pre-implementation-incident-recall,gitnexus-reviewer,graphiti-reviewer,security-quorum,pre-commit-adversarial-pass,post-commit-verify-handoff,post-commit-build-summary`. Library agents (the 3 security specialists) come along for the ride when `security-quorum` is enrolled.
  - `--target=<host-path>` → override the auto-detected enrollment target directory. Useful for non-ddev projects or per-project enrollment overrides. Path must exist and be writable from host.

## Completion Output

```
✓ Installed N playbook(s) to .claude/:
    - gitnexus.md (reachable, 3 repos indexed)
    - graphiti.md (reachable, Neo4j connected)
✓ Updated fenced section in .claude/CLAUDE.md (pb-hcf, replaces legacy pb-gitnexus if present)
✓ Migrated legacy pb-gitnexus fence (if found)
✓ Hook enrollments (.claude/agents/):
    - gitnexus-reviewer  → post-implementation (order 30, mode single)   [newly enabled]
    - security-quorum    → post-implementation (order 70, mode single)   [unchanged]
    (Pass --enable=<name>[,<name>] to add more, --enable-all for both bundled agents.)
✓ Wrote .claude/wires.json registry

Reachability summary:
  gitnexus  : ✓ http://gitnexus:4747/ (200, 3 repos)
  graphiti  : ✓ mcp__graphiti__get_status (ok)

Next: /hcf:plan-create as usual. HCF's agents will consult the per-domain
playbooks when their task neighborhood matches, and any enrolled pb-hcf
agents fire at their declared hook. To verify wiring loaded:

  cat .claude/CLAUDE.md | grep -A1 "pb-hcf:start"
  cat .claude/wires.json | jq '.playbooks, .enrollments'
  ls .claude/agents/
```

## What this skill does NOT do

- **No silent agent enrollment.** Bundled pb-hcf agents only land in `.claude/agents/` when `--enable=<name>` is passed.
- **No edits to HCF's central plugin files.** HCF upstream stays clean.
- **No `.claude/pipeline.md` writes — ever.** That file is legacy in HCF v2.0.0+ and HCF gates the planning workflow while it exists. Migration is `/hcf:project-update`'s job, not this skill's.
- **No edits to `~/claude-skills-central/mcps/.mcp.json`.** Central MCP config is managed separately; this skill only writes per-project context.
- **No container management.** Probes only; does not start / stop / build.
- **No automatic re-wire on plugin update.** When pb-hcf bumps version and ships new playbooks, run `/pb-hcf:wire` manually in each project to pick them up.
