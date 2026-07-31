# Plan: pb-hcf v0.5.0 — Verification Spine + Upstream Quality

## Created
2026-07-31

## Status
completed

## Objective
Ship pb-hcf v0.5.0: close the verification gaps found in the 2026-07-29 tooling audit (pipeline-fire proof, mutation gate, runtime-error gate) and add upstream-quality stages (pre-mortem, interview, constitution) — all portable, wire-enrollable, HCF-source-untouched.

## Related Issues
none (tracked via host task #6 + memory project_tooling_audit_2026_07_29.md)

## Discovery Notes
Repo at 0.4.9: 13 agents, skills/wire, templates/{captainhook,playbooks}, services/bugsink (live on host :7788, API smoke-tested, README documents DSN/token pattern), scripts/discover-hooks.sh + hooks/discover-hooks.sh. Greenfield: 4 new agents, 2 new skills, 3 new template families.

**CRITICAL enrollment convention (verified against source):** pb-hcf agents ship DORMANT — their source files at `agents/<name>.md` carry `name/description/model/tools` ONLY, NOT `phase/order/mode`. Intended phase/order is documented in the agent BODY prose ("You run at post-implementation, order 40"). `phase/order/mode` is stamped into a COPY at enrollment time by `/pb-hcf:wire --enable=<name>`, sourced from the enrollable-agent table in `skills/wire/SKILL.md` (step 4, lines 91-104) + the `--enable-all` list (line 213). `scripts/discover-hooks.sh` line 101 skips any agent file with no `phase:` — so a new agent is invisible to the pipeline until (a) it is added to the wire enrollable table AND (b) wire --enable stamps it. Any task whose "test" says an agent "carries frontmatter phase X" is WRONG per this convention — the agent ships without phase; the wire table + task 014 register it.

Conventions to follow: agent source frontmatter keys `name/description/model/tools` (NO phase/order/mode); playbooks declare "Authority scope"; services ship compose+README; wire records probes into `.claude/wires.json`.

Existing enrolled orders (from source): pre-plan → pre-flight-check 5, pre-plan-graphiti-recall 10, devils-advocate 10 (HCF), post-plan-manual-test-plan 50; post-implementation → gitnexus-reviewer 30, graphiti-reviewer 40, standards-enforcer 50 (HCF, untouchable), security-quorum 70; pre-commit → pre-commit-adversarial-pass 10; post-commit → verify-handoff 10, build-summary 20. **New-agent orders (collision-checked): pre-mortem post-plan 20 (free), mutation-tester post-implementation 45 (NOT 40 — 40 is taken by graphiti-reviewer), issue-sentinel post-batch 30 (free, first at this hook), pipeline-audit post-commit 90 (free, tail).**

## Scope
### In Scope
- Agents: pre-mortem (post-plan), pipeline-audit (post-orchestration/post-commit tail), mutation-tester (post-implementation), issue-sentinel (post-batch)
- Skills: interview (pre-plan scope builder), modernization-sweep (rector apply-mode)
- Templates: rector/ (dist config + skip rules + phpstan ratchet doc), constitution.md, otel env
- Wire extensions: bricklayer probe, bugsink probe, constitution injection via pre-flight-check
- Playbooks: bricklayer template seeded; gitnexus template gains bricklayer cross-ref
- services/otel/ docs (collector optional, mirrors bugsink pattern)
- Version bump + CHANGELOG + README
### Out of Scope
- HCF source changes (integration layer only)
- Per-project application (pps rector.php tuning, justbetter module installs — post-release per-project work)
- OTel collector implementation (docs + env template only)
- Graphiti Neo4j backup (separate TODO)

## Success Criteria
- [ ] All new agents ship DORMANT (valid frontmatter, NO phase/order/mode key) and are registered in the wire enrollable table + --enable-all list (task 014)
- [ ] After `wire --enable-all` on a scratch project, `scripts/discover-hooks.sh` lists all 4 new agents at their declared hooks/orders with NO order collisions (mutation-tester 45, not 40)
- [ ] Wire run on a scratch project records bricklayer + bugsink probes in wires.json
- [ ] pipeline-audit can locate a discoverable evidence artefact for every enrolled agent (new agents write _mutation_tester.md / _issue_sentinel.md; inline-only reviewers via commit trailer)
- [ ] All shell snippets shellcheck-clean; all JSON valid
- [ ] CHANGELOG documents every feature; README index + plugin.json/marketplace.json descriptions (14 agents, post-batch hook) updated
- [ ] Version 0.5.0 in plugin.json + marketplace.json

## Task Overview
| Task | Description | Depends On | Status |
|------|-------------|------------|--------|
| 001 | Bricklayer playbook template + gitnexus cross-ref | - | completed |
| 002 | Wire: bricklayer probe | 001 | completed |
| 003 | pre-mortem agent | - | completed |
| 004 | pipeline-audit agent | - | completed |
| 005 | mutation-tester agent + infection template | - | completed |
| 006 | Constitution template + pre-flight-check injection | - | completed |
| 007 | interview skill (clarity-scored scope builder) | - | completed |
| 008 | Wire: bugsink probe + release-tagging convention | 002 | completed |
| 009 | issue-sentinel agent + magento2-sentry install doc | 002, 008 | completed |
| 010 | Rector templates (dist config, skip rules, phpstan ratchet) | - | completed |
| 011 | Rector enforcement wiring (post-batch check + standards-enforcer consumption + tdd-worker context) | 010 | completed |
| 012 | modernization-sweep skill | 010 | completed |
| 013 | OTel env template + services/otel README | - | completed |
| 014 | Release: version bump, CHANGELOG, README, wire --enable table update | 001-013 | completed |

## Architecture Notes
- Agents enroll ONLY via wire --enable copy with frontmatter stamped; defaults dormant (HCF convention). New-agent source files (003/004/005/009) carry NO phase/order/mode — task 014 registers them in the wire enrollable table + --enable-all list so wire can stamp them.
- **Wire SKILL.md is edited by multiple tasks (002, 008 probes; 006 install-mention; 011 fence pointer; 014 enrollable-table registration).** These touch DISJOINT named sections. 002+008 both add to the reachability probe table + wires.json shape → 008 depends on 002 to serialize that shared section. 006/011 touch different sections → coordinate via anchored Edits (re-read before edit; touch only your named section). 014's enrollable-agent registration runs last (depends on all).
- **Evidence trail for pipeline-audit (004):** every enrolled agent must leave a discoverable artefact so pipeline-audit can prove it fired. Existing file-writers: devils-advocate→_devils_advocate.md, pre-mortem→_pre_mortem.md, manual-test-plan→test-plans/<ticket>.yml. New agents that would otherwise emit inline-only verdicts MUST write a plan-dir artefact: mutation-tester→_mutation_tester.md, issue-sentinel→_issue_sentinel.md. pipeline-audit maps each enrolled agent to its artefact; inline-only reviewers (gitnexus/graphiti/security) are evidenced via commit-message trailer.
- **Custom-namespace scope (005/011/012):** "changed custom-namespace PHP files" = git-changed `*.php` under `app/code/`, excluding `generated/`, `vendor/`, and test fixtures. Deterministic default needs no config; an optional project override may extend the root list. All three tasks use this same definition.
- issue-sentinel reads env from ~/.pb-hcf/bugsink.env (host) / mounted equivalent (container); never hardcodes DSN/token.
- Release tag convention: HCF_RELEASE=<plan-name>#<batch> exported by orchestration wrapper doc; issue-sentinel + magento2-sentry both consume it.
- Rector layers: deterministic check (script) is separate from judgment (standards-enforcer) — script fails loud, agent interprets.
- Chatroom posting from pipeline-audit uses existing chatroom MCP tools; degrade to file report if MCP absent.

## Risks & Mitigations
- Magento-specific rector sets immature: task 010 verifies at implementation time; fallback = generic PHP 8.3 sets + explicit Magento skip-rules.
- Infection runtime cost: changed-files-only + --min-msi threshold + timeout; documented as post-implementation (once per plan), not per-batch.
- v1.1.1 vs v2 HCF host split-brain: all enrollment is frontmatter-based (v2); v1.1.1 hosts simply won't discover the hooks — non-breaking.
- Bugsink unreachable in a project: issue-sentinel must PASS-with-note, not block (probe recorded in wires.json gates enrollment advice).
