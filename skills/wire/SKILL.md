---
name: wire
description: Wire HCF agents (devils-advocate, tdd-worker, standards-enforcer, plus pb-hcf's gitnexus-reviewer post-implementation agent) into the fleet's per-domain playbooks (gitnexus, graphiti, security, …) by installing playbook files into .claude/<name>.md, appending a single fenced section to .claude/CLAUDE.md pointing to each, and recording wire state in .claude/wires.json. Multi-playbook successor to the per-plugin wire skills (replaces /pb-gitnexus:wire). Run AFTER /hcf:project-setup.
disable-model-invocation: true
---

# /pb-hcf:wire

Install pb-hcf's fleet playbooks into the current project so HCF's existing agents (devils-advocate, tdd-worker, standards-enforcer) and pb-hcf's bundled gitnexus-reviewer agent pick up the per-domain guidance via context. This is the consolidated replacement for `/pb-gitnexus:wire` — one skill installs ALL playbooks under `pb-hcf/templates/playbooks/` instead of one skill per plugin.

**Architectural note:** This skill does NOT override any agent under `.claude/agents/`. In DDEV envs `.claude/agents/` is typically read-only-mounted. Wiring happens via project-local `.claude/<playbook>.md` files referenced from `.claude/CLAUDE.md` — HCF's default agents auto-load CLAUDE.md, follow the pointers, and pick up the per-domain rules transitively. Same pattern as pb-gitnexus used.

## Prerequisites Check

Abort with a clear message if any fail:

1. **Run from project root** — current working directory contains a recognisable project marker (`composer.json`, `package.json`, `pyproject.toml`, `.git/`).
2. **HCF project-setup has run** — `.claude/CLAUDE.md` must exist (created by `/hcf:project-setup`). If absent, tell user to run `/hcf:project-setup` first and stop.
3. **Plugin install path resolvable** — `$CLAUDE_PLUGIN_ROOT/templates/playbooks/` must be readable and contain at least one `*.md` file. If empty, this install is corrupt — tell user to `/plugin reinstall pb-hcf`.

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

### 3. Write `.claude/wires.json` registry

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
  ]
}
```

This file is the **wire registry** — downstream skills like `/proxiblue-skills:workflow-build-feature` pre-flight, and CI checks, can read it to verify everything's still up before kicking off a long run. Updated every wire / re-wire / re-probe.

### 4. Detect + replace legacy `pb-gitnexus:` fence (migration)

If `.claude/CLAUDE.md` contains a legacy `<!-- pb-gitnexus:start --> ... <!-- pb-gitnexus:end -->` block from the deprecated wire, remove it before writing the new `pb-hcf:` fence. Report this as `migrated legacy pb-gitnexus fence → pb-hcf fence` in the completion output. Also clean up `.claude/gitnexus.json` if present (renamed semantically — its data is now in `.claude/wires.json`).

### 5. Do NOT write to `.claude/agents/`

That directory is typically a read-only centralised mount in DDEV envs. Agents read project-local `.claude/<playbook>.md` from CLAUDE.md context — that's all that's needed.

### 6. Report what changed

List each created / modified / removed file with a one-line summary. Include reachability state per playbook and the recommended fix for any that probed as unreachable.

## Idempotency

- Re-running is safe. Fenced section replaces, not duplicates. `wires.json` is rewritten with fresh timestamp + current probe state.
- For overwritten playbook files, show the diff and confirm unless `--no-overwrite` is passed.
- Flags:
  - `--reprobe` → re-run only the reachability probes, update `wires.json`, don't touch playbook files or CLAUDE.md.
  - `--no-overwrite` → skip diff prompts; leave existing playbook files untouched if they differ.
  - `--migrate-only` → only run the legacy `pb-gitnexus:` fence migration step (step 4), don't install or probe anything.

## Completion Output

```
✓ Installed N playbook(s) to .claude/:
    - gitnexus.md (reachable, 3 repos indexed)
    - graphiti.md (reachable, Neo4j connected)
✓ Updated fenced section in .claude/CLAUDE.md (pb-hcf, replaces legacy pb-gitnexus if present)
✓ Wrote .claude/wires.json registry
✓ Migrated legacy pb-gitnexus fence (if found)

Reachability summary:
  gitnexus  : ✓ http://gitnexus:4747/ (200, 3 repos)
  graphiti  : ✓ mcp__graphiti__get_status (ok)

Next: /hcf:plan-create as usual. HCF's agents will now consult the per-domain
playbooks when their task neighborhood matches. To verify wiring loaded:

  cat .claude/CLAUDE.md | grep -A1 "pb-hcf:start"
  cat .claude/wires.json | jq .playbooks
```

## What this skill does NOT do

- **No agent overrides.** RO-mount-safe.
- **No edits to HCF's central plugin files.** HCF upstream stays clean.
- **No edits to `~/claude-skills-central/mcps/.mcp.json`.** Central MCP config is managed separately; this skill only writes per-project context.
- **No container management.** Probes only; does not start / stop / build.
- **No automatic re-wire on plugin update.** When pb-hcf bumps version and ships new playbooks, run `/pb-hcf:wire` manually in each project to pick them up.
