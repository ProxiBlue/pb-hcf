# pb-hcf

Context-wire bundle that gives HCF's autonomous workflow access to a code graph (GitNexus), a temporal knowledge graph (Graphiti), and a multi-agent security quorum. HCF source files are not modified — extensions land via project-local `.claude/<playbook>.md` files referenced from a fenced section in `.claude/CLAUDE.md`, plus opt-in drop-in agents that enroll into HCF v2.0.0+'s frontmatter-based hook pipeline.

> **HCF v2.0.0 compatibility (2026-06-26).** HCF dropped `.claude/pipeline.md`. Agents now declare hook membership via YAML frontmatter (`phase:` / `order:` / `mode:`) — see [HOOKS.md upstream](https://github.com/markshust/hcf#pipeline). `/pb-hcf:wire` enrolls bundled agents by stamping that frontmatter into `.claude/agents/<name>.md` overrides only when `--enable=<name>` is passed (default: off). If a legacy `.claude/pipeline.md` exists, `/pb-hcf:wire` refuses to run and points the user at `/hcf:project-update` to migrate first.

## What's in the plugin

| | Type | What |
|---|---|---|
| `/pb-hcf:wire` | skill | Multi-playbook installer + opt-in HCF v2 hook enrollment. Discovers `templates/playbooks/*.md`, copies each to `.claude/<name>.md`, appends a single fenced section to `.claude/CLAUDE.md` pointing to all of them, writes `.claude/wires.json` registry, runs per-domain reachability probes. With `--enable=<name>[,<name>]`, copies the named bundled agent(s) to `.claude/agents/<name>.md` with `phase`/`order`/`mode` stamped. |
| `gitnexus-reviewer` | agent | Diff-impact reviewer using the GitNexus code graph. Suggested enrollment: `phase: post-implementation`, `order: 30`, `mode: single`. Opt in via `/pb-hcf:wire --enable=gitnexus-reviewer`. Surfaces indirect callers grep misses (plugins, observers, DI preferences). |
| `security-quorum` | agent (orchestrator) | Spawns the 3 security specialists in parallel, runs 2-round 2-of-3 consensus, synthesises a single PASS / FAIL / NEEDS-REVIEW verdict, writes one verdict episode to graphiti. ~$0.30-1.00 per run. Suggested enrollment: `phase: post-implementation`, `order: 70`, `mode: single`. Opt in via `/pb-hcf:wire --enable=security-quorum` or call ad-hoc via `Task`. |
| `security-static-analyst` | agent (specialist, 1 of 3) | Reads code + traces data flows from sources to sinks. Cites file:line. Uses gitnexus impact + graphiti incident recall. Read-only. |
| `security-adversarial-tester` | agent (specialist, 2 of 3) | Hostile-actor angle. Builds exploit payloads + attack chains. Online CVE lookups (NVD, GitHub Advisory DB, OSV). Native audit tools (composer/npm/pip-audit). Read-only — no actual exploitation. |
| `security-defensive-auditor` | agent (specialist, 3 of 3) | Pass-then-verify discipline. Walks each framework-provided defense (Magento ACL, form_key, escapeHtml, CSP, crypto) and confirms it fires correctly, not just imports. Read-only. |
| `templates/playbooks/gitnexus.md` | playbook | Domain rules + per-agent guidance for using GitNexus MCP tools. Authoritative on code-structure / caller / impact questions. |
| `templates/playbooks/graphiti.md` | playbook | Domain rules for using Graphiti MCP. Authoritative on discussion / decision / intent / planned-but-not-built questions. |
| `templates/playbooks/security.md` | playbook | OWASP / vulnerability assessment. Describes the 3-specialist quorum + 2-of-3 consensus rule + integration points. Authoritative on how to gate workflow on security verdict. |
| `templates/playbooks/playwright.md` | playbook (future) | E2E test design and coverage. |

## Authority scope model

Each playbook declares — at the top, as a fixed section — what it is the source of truth for and what it explicitly defers to siblings. This avoids contradictory guidance when multiple playbooks are wired together. When adding a new playbook, copy the existing `## Authority scope` skeleton and fill in the matching defer-to lines.

## How HCF flows change with pb-hcf wires

Vanilla HCF is a complete flow on its own. pb-hcf doesn't replace it — pb-hcf gives HCF's existing agents better tools (gitnexus + graphiti MCP context) and adds a security quorum at HCF's native `post-implementation` hook (enrolled via agent frontmatter; default off). HCF source files are not modified.

The two side-by-side diagrams below cover the user-visible flow. Everything pb-hcf adds is annotated with `◄── pb-hcf`.

### Vanilla HCF (no pb-hcf wires)

```
User: "build feature X"
  │
  ▼
/hcf:plan-create
  ├─ Phase 1: Discovery (codebase glob + read; permutation brainstorm)
  ├─ Phase 2: Grounded Clarification (ask user)
  ├─ Phase 3: Define _plan.md
  ├─ Phase 4: Break down into per-task .md files
  ├─ Phase 5: Validate dependencies
  ├─ Phase 6: Post-plan pipeline (devils-advocate — grep-only)
  ├─ Phase 7: User reviews plan
  └─ Phase 8: Finalize
  │
  ▼
/hcf:plan-orchestrate <plan>
  ├─ Spawn parallel tdd-workers per task:
  │     ├─ RED → GREEN → REFACTOR
  │     └─ Run FULL project test suite per task
  ├─ Loop until all tasks complete
  └─ Post-implementation pipeline:
        ├─ standards-enforcer over the diff
        └─ Full test suite again
        ▼
        Single final commit
```

Wired by default: `standards-enforcer` in post-implementation. That's it. No graphiti consultation, no gitnexus consultation, no security audit, no prior-decision recall.

### Adjusted process (pb-hcf wired)

```
User runs /proxiblue-skills:workflow-onboard-project   ◄── ONE TIME per project
  │
  ├─ Install plugins: pb-hcf, pb-hcf-playwright-tdd, proxiblue-skills, hyva-ai-tools
  ├─ /hcf:project-setup → .claude/CLAUDE.md
  ├─ /pb-hcf-playwright-tdd:setup → .claude/testing.md
  └─ /pb-hcf:wire --enable=gitnexus-reviewer,security-quorum   ◄── pb-hcf
        ├─ Drops .claude/{gitnexus,graphiti,security}.md
        ├─ Single fenced section in .claude/CLAUDE.md pointing to all of them
        ├─ Runs reachability probes (gitnexus:4747, mcp__graphiti__get_status)
        ├─ Enrolls each --enable'd bundled agent into HCF's hook pipeline:
        │     copies $PLUGIN/agents/<name>.md → .claude/agents/<name>.md
        │     and stamps phase: post-implementation / order / mode in frontmatter
        └─ Writes .claude/wires.json registry (playbooks[] + enrollments[])


User runs /proxiblue-skills:workflow-build-feature <ticket>
  │
  ├─ PRE-FLIGHT   ◄── pb-hcf: registry-driven, scales to N playbooks
  │   └─ Loop .claude/wires.json — probe each entry; STOP if any fail
  │
  ├─ Create feature branch from live
  │
  ├─ /hcf:plan-create
  │      ├─ Phase 1: Discovery   ◄── now playbook-aware
  │      │   ├─ Codebase glob (vanilla HCF)
  │      │   ├─ pb-hcf: graphiti search → "Discussed but not yet built",
  │      │   │         prior decisions, past incidents, vendor / client constraints
  │      │   └─ pb-hcf: gitnexus impact for any class / method mentioned
  │      │
  │      ├─ Phase 3: Define plan   ◄── plan carries Historical Context preamble
  │      │
  │      ├─ Phase 6: devils-advocate   ◄── multi-playbook critique
  │      │   ├─ gitnexus: indirect callers, plugin/observer/DI wiring
  │      │   ├─ graphiti: adjacent planned work, conflicts, prior incidents
  │      │   └─ security: scope-relevance flag if auth/payments/secrets touched
  │      │
  │      └─ SubagentStop hook fires → captures findings to graphiti
  │
  ├─ [USER REVIEW] Plan + devils-advocate findings + Historical Context
  │
  ├─ /manual-test-plan → posts to GH ticket
  ├─ [USER REVIEW] ticket comment
  │
  ├─ /hcf:plan-orchestrate <plan>   ◄── HCF NATIVE
  │      ├─ Spawn parallel tdd-workers per task:
  │      │     ├─ pb-hcf: graphiti search for prior incidents in same area
  │      │     ├─ pb-hcf: gitnexus find_symbol + impact before modifying classes
  │      │     ├─ RED → GREEN → REFACTOR (HCF native)
  │      │     ├─ Targeted tests (per-project testing.md scoping)
  │      │     └─ SubagentStop hook → captures non-obvious blockers
  │      │
  │      └─ Post-implementation pipeline (HCF v2 frontmatter-enrolled agents):
  │             ├─ standards-enforcer (vanilla HCF — opt-in via frontmatter)
  │             ├─ pb-hcf: gitnexus-reviewer (order 30) — impact-graph review of whole diff
  │             ├─ pb-hcf: security-quorum (order 70)   ◄── 2-of-3 consensus gate
  │             │       ├─ Round 1 parallel spawn of 3 specialists:
  │             │       │   ├─ security-static-analyst (data-flow + file:line)
  │             │       │   ├─ security-adversarial-tester (payloads + CVE lookup)
  │             │       │   └─ security-defensive-auditor (pass-then-verify controls)
  │             │       ├─ Round 2 parallel re-spawn with sibling votes (revise)
  │             │       ├─ Verdict synthesis (2-of-3 rule, dissents preserved)
  │             │       └─ Write ONE verdict episode to graphiti
  │             │
  │             └─ Full test suite ONCE
  │             ▼
  │             Single final commit
  │
  ├─ [USER ACTION] Open fresh thread → /verify-feature <ticket>
  ├─ [USER REVIEW] verify-feature outcome
  │
  ├─ Quality gates (optional):
  │   └─ /workflow-security-audit (gitnexus-aware single-agent — second pass)
  │
  └─ Build-complete summary


ALWAYS-ON (per session, via pb-graphiti hooks):
  ├─ SessionStart hook   — graphiti recall ([project, fleet] or [host, fleet])
  ├─ TaskCompleted hook  — Claude Code task → graphiti episode (3-cap)
  ├─ SubagentStop hook   — every Task spawn return → graphiti episode (2-cap)
  ├─ SessionEnd hook     — session terminate → graphiti episode (8-cap)
  └─ PreCompact hook     — rarely fires on 1M context; still wired for smaller models
```

### Side-by-side per-phase

| HCF phase | Vanilla | With pb-hcf wires | Net change |
|---|---|---|---|
| Onboard | Manual install per project | One workflow chains plugin installs + wire + setup | More automation, one entry point |
| Pre-flight before plan | None | Loop `wires.json` registry, probe each playbook's MCP | Stop early if stack broken |
| plan-create Phase 1 Discovery | Codebase glob + brainstorm | + graphiti recall for planned/discussed/prior-decisions + gitnexus impact | Foresight gap closed — plan considers future-intent |
| plan-create Phase 6 devils-advocate | Grep-only review | + gitnexus indirect-caller chase + graphiti adjacent-work + security scope flag | Multi-source critique |
| plan-orchestrate workers | grep + read | + gitnexus find_symbol/impact + graphiti incident recall | Workers consult institutional memory |
| plan-orchestrate worker tests | Full project suite per task | Targeted scoped tests per task (testing.md) | Avoids parallel-collision when project's testing.md is configured for it — see "Open concerns" |
| plan-orchestrate post-implementation | standards-enforcer (dormant by default in HCF v2) | + gitnexus-reviewer (order 30) + security-quorum (order 70), both enrolled via `/pb-hcf:wire --enable=...` | Real security gate that scales |
| Test suite at plan-end | Full suite | Full suite (unchanged from vanilla) | — |
| Commit | Single commit at plan-end | Single commit at plan-end | Unchanged |
| Session lifecycle writes to graphiti | None | SessionStart recall + TaskCompleted / SubagentStop / SessionEnd consolidation | Long-term memory accumulates |

### What's gained vs vanilla HCF

| Capability | How |
|---|---|
| Foresight on plan creation (planned/discussed features influence current design) | graphiti search in plan-create Phase 1 |
| Indirect-caller awareness in plan-review + workers | gitnexus impact via wire |
| Prior-incident recall when implementing | graphiti search in tdd-worker per task |
| Multi-source critique by devils-advocate | three playbooks consulted simultaneously |
| Multi-agent security gate with quorum (2-of-3) | `security-quorum` agent enrolled at HCF `post-implementation` hook |
| Verdict provenance preserved across runs | `security-quorum` writes one episode per audit; next audit sees it |
| Pre-flight stack health check (scales to N wires) | `wires.json` registry loop (includes `enrollments[]`) |
| Session-decision capture | SubagentStop + SessionEnd hooks (pb-graphiti) |
| No parallel-dev work vs HCF | All extensions via context + project-local agent overrides; HCF source untouched |
| Authority Scope hygiene | Each playbook declares its truth domain — no contradictory guidance |

### Open concerns

These are real trade-offs the design accepts. Revisit when they bite in practice.

**Per-task review granularity.** `gitnexus-reviewer` enrolls at HCF's `post-implementation` hook, which fires once at batch-end, not after every task. If a tdd-worker introduces a regression in task 3 of 5, the reviewer surfaces it only after task 5 finishes — slower feedback than a per-task gate would give. (HCF's `post-batch` hook fires per batch; if the per-batch cadence matters more than per-task, switch the agent's `phase` to `post-batch` in `.claude/agents/gitnexus-reviewer.md`.) The trade is that no HCF wrapping is needed; HCF source stays clean.

**Parallel-test resource collision.** HCF defaults run the full project test suite at end of each `tdd-worker` task AND again in post-implementation. Under parallel worker dispatch this can collide on shared MariaDB rows, Redis cache, OpenSearch indexes, Playwright sessions, `var/` artefacts. Mitigation lives in each project's `.claude/testing.md` — scope test commands to targeted invocation (per-file / per-testsuite) rather than full-suite, so workers don't all hit the whole DB. Or run with `--max-parallel 1` if the project's HCF supports it.

### When NOT to use pb-hcf wires

- **Non-Magento project, no graphiti corpus.** `/hcf:plan-orchestrate` direct is fine.
- **Quick spike / throwaway code.** Wiring adds discipline that costs ~$0.30-1.00 per plan; not worth it for a 10-line experiment.
- **Pre-release security sign-off.** Use a heavier full-OWASP quorum (e.g. `/agent-teams team_security` from the proxiblue-skills central catalogue) — `security-quorum` is the per-plan gate, not the release-readiness audit.

## What pb-hcf is NOT

- **Not a wrapper for HCF flows.** No `plan-orchestrate` substitution. The security + reviewer agents enroll into HCF's native v2 hook pipeline via agent frontmatter (opt-in via `--enable`).
- **Not a clone of HCF.** All HCF source files (agents, skills) stay upstream-clean.
- **Not a marketplace.** Lives as a single plugin; install via the standard plugin marketplace flow.
- **Does not touch `.claude/pipeline.md`.** That file is legacy in HCF v2.0.0+ — `/hcf:project-update` is the only thing allowed to migrate or remove it. `/pb-hcf:wire` refuses to run while it exists.

## Adding a new playbook

1. Write `templates/playbooks/<name>.md`. First section MUST be `## Authority scope` declaring what this playbook owns + what it defers to siblings.
2. Add a probe row to `skills/wire/SKILL.md` (`Per-playbook reachability probes` table) if the domain has a probeable MCP / service.
3. Bump pb-hcf version, commit, push.
4. Re-run `/pb-hcf:wire` in each project to pick up the new playbook.

No other plugin needs to change. Wire registry auto-discovers; CLAUDE.md fence auto-rewrites with a pointer for the new playbook; pre-flight checks pick it up via `wires.json`.

## Status

| Version | What landed |
|---|---|
| v0.1.0 | gitnexus-reviewer agent + gitnexus.md playbook + graphiti.md playbook + multi-playbook `wire` skill. |
| v0.2.0 | Security quorum: `security-quorum` orchestrator + 3 specialist agents + `security.md` playbook. 2-of-3 consensus, ~$0.30-1.00 per run. |
| v0.3.0 | **BREAKING — aligned with HCF v2.0.0.** Wire no longer writes `.claude/pipeline.md` (that file blocks HCF planning in v2). Replaced with opt-in HCF v2 hook enrollment via agent frontmatter: `/pb-hcf:wire --enable=<name>[,<name>]` (or `--enable-all`) copies the named bundled agent to `.claude/agents/<name>.md` with `phase: post-implementation` + `order` + `mode` stamped. Wire halts if a legacy `pipeline.md` is present and tells the user to run `/hcf:project-update` first. `wires.json` gains `enrollments[]` for downstream pre-flight visibility. Graphiti playbook adds search-discipline guidance. |

Next planned playbook: `playwright.md` — folds in E2E test design and coverage guidance.
