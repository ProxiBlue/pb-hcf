# Security Quorum Integration

This project is wired with pb-hcf's security quorum — a 3-specialist read-only audit (Static Analyst + Adversarial Tester + Defensive Auditor) that requires 2-of-3 consensus before reporting PASS. A single agent's voice is not enough; the quorum exists because security findings have too much downside from a single biased reviewer.

## Authority scope

This playbook is the source of truth for:
- **OWASP Top 10 audit** of the project's diff or scope (A01–A10).
- **Vulnerability assessment**: how to invoke the quorum, what verdict to trust, how to gate workflow on the verdict.
- **Dependency CVE inspection** — composer / npm / pip / go-mod manifests against NVD / GitHub Advisory DB / OSV.
- **Controls verification** — pass-then-verify discipline on framework-provided defenses (Magento ACL, form_key, escapeHtml, CSP, session backend, crypto primitives).

This playbook is NOT the authority for (defer to sibling playbooks):
- **Code structure / who calls what** → `codegraph.md` — the security agents USE `mcp__pb-codegraph__impact` internally, but the authoritative code-graph view lives in codegraph.md.
- **Prior incidents / decisions about controls** → `graphiti.md` — the security agents query graphiti for past CVE/incident facts and prior control decisions, but graphiti is the authoritative source on intent + history.
- **E2E test design / coverage** → `playwright.md` (when wired).

When a finding cites both codegraph impact AND graphiti incident recall, surface both — the multi-source citation is exactly what the quorum is meant to produce.

## Mandatory prior-incident recall (query graphiti BEFORE planning or reviewing auth-touching code)

Any agent that consults this playbook — a quorum specialist, a pre-plan reviewer (`devils-advocate`), or an ad-hoc auditor — MUST query graphiti for prior incidents and standing rules the moment a plan or diff touches **authentication, login, session, password, credential, or 2FA/MFA** code. This is not optional recall: an incident that recurs because nobody queried is exactly the failure this block exists to prevent.

- Call `mcp__graphiti__search_memory_facts` AND `search_nodes` with `group_ids=[<project-id>, "fleet"]`.
- Keyword sweep — try several, vocabulary varies: `2fa`, `TOTP`, `MFA bypass`, `login`, `session`, `authentication`, `re-enrollment`, `credential overwrite`.
- Treat any hit as a **control requirement** in the plan/findings, not a footnote. Cite the fact.

Standing fleet rule (seeded from a real incident — ai_assistant/webhooks, 2026-07-12): **a second factor must never be overwritable or re-enrollable by a session that has only passed the password stage.** Enrolling a NEW authenticator is allowed ONLY when no secret exists yet; if one already exists, force verification of the EXISTING factor. Re-enrollment / lost-device flows require a FULLY authenticated session (password re-entry or backup code), never a pending-2FA session. Verify this specific control on any login/2FA change — a stage-1-only gate cannot guard a stage-2 credential mutation.

## The quorum agents

Three specialist agents bundled with pb-hcf, each taking a different angle so consensus is earned, not parroted:

| Agent | Angle | Cited by |
|---|---|---|
| `security-static-analyst` | Reads code, traces data flows from sources (HTTP params, uploads, webhook bodies) to dangerous sinks (SQL, exec, template, deserialise, IDOR). Cites file:line for every claim. Uses codegraph `impact` to chase indirect callers grep misses. | findings.file + findings.line |
| `security-adversarial-tester` | Assumes hostile actor. Writes exploit payloads + attack chains. Online CVE lookups (NVD, GitHub Advisory DB, OSV) for dependency-version vulnerabilities. Runs native audit tools (`composer audit`, `npm audit`). | payload + cve list |
| `security-defensive-auditor` | Verifies framework defenses + mitigations *already present* — pass-then-verify discipline. Walks each control and confirms it fires correctly, not just imports. | controls_verified list |

A 4th agent — `security-quorum` — is the orchestrator. It spawns the 3 specialists, runs 2 rounds (independent vote, then evidence-based revision), synthesises the verdict per the consensus rule, writes one verdict episode to graphiti, returns the final report. **You invoke `security-quorum`, not the specialists directly.**

## When to invoke

Pick the integration point per project. Both work; choose by where you want the gate:

### Option A — `pipeline.md` post-implementation slot (recommended for HCF plans)

Add to the project's `.claude/pipeline.md`:

```markdown
## post-implementation
- standards-enforcer
- security-quorum
- codegraph-reviewer
```

HCF's `/hcf:plan-orchestrate` Phase 6 picks them up automatically. Runs at batch end over the whole diff. The quorum's verdict surfaces in the orchestration summary; FAIL doesn't auto-block the commit (HCF doesn't gate on agent output) but it surfaces prominently so the user can intervene.

### Option B — `workflow-build-feature` quality gate

Add to `QUALITY_GATES` in the workflow:

```
QUALITY_GATES = [
  "security-quorum",      # 3-agent OWASP audit; PASS required to proceed
  "workflow-security-audit",  # OPTIONAL second pass (single-agent codegraph-aware)
]
```

`workflow-build-feature` evaluates each gate's output. A `FAIL` from `security-quorum` stops the build before completion summary; `NEEDS-REVIEW` continues but flags in summary; `PASS` / `PASS-WITH-NOTES` proceeds.

### Option C — manual invocation (ad-hoc audits)

From any Claude Code session:

```
Task(subagent_type=security-quorum,
     prompt="audit_target: <git diff or path>; task_context: <ticket or 'ad-hoc audit'>")
```

Returns the full report directly to the calling session. Useful for pre-PR audits or post-deploy retrospectives.

## Verdict matrix (the gating logic)

| Round 2 vote distribution | Quorum verdict | Pipeline action |
|---|---|---|
| 3 × PASS | PASS | proceed |
| 2 × PASS + 1 × NEEDS-REVIEW | PASS-WITH-NOTES | proceed; surface dissent |
| 2 × PASS + 1 × FAIL (critical, unrebutted) | NEEDS-REVIEW | proceed but surface prominently |
| 2 × FAIL (any) | FAIL | stop; address findings before continuing |
| 3 × FAIL | FAIL | stop; serious problem |
| 3-way split | NEEDS-REVIEW with escalation | user reviews findings; re-run quorum after triage |

**Single-voice override is not allowed.** This is the entire point of the quorum.

## Cost per fire

| Mode | Approx cost (Haiku/Sonnet 4.5 mix) | Wall time |
|---|---|---|
| Per HCF plan (post-implementation slot) | ~$0.30-1.00 | ~3-8 min |
| Per workflow-build-feature run | same | same |
| Ad-hoc audit | same | same |

Costs scale with audit_target size — a 500-line diff is cheap; a "audit the whole module" run can hit the upper end. Cap at one quorum run per plan unless a re-run is justified by fix application.

Compared to siblings:
- **Single `/security-review`** — single voice, no quorum. Cheaper (~$0.05-0.10) but the single-bias problem this playbook exists to solve.
- **`team_security` 21-agent quorum** — 7 trios × 3 agents covering OWASP per-domain. ~$5-15/run. Use for release sign-offs and compliance audits; this playbook covers everyday plan-end gating.

## What the quorum WILL catch reliably

- SQL injection, OS command injection, deserialisation, path traversal (Static Analyst tracing + Adversarial Tester payloads)
- Missing authn/authz / IDOR / vertical privilege escalation (Defensive Auditor walking controls + Static Analyst tracing controller entry)
- XSS in PHTML / template output (Static Analyst walking output sinks)
- CSRF on state-changing endpoints (Defensive Auditor verifying form_key + SameSite)
- Dependency CVEs with available patches (Adversarial Tester online lookup + native audit tools)
- Hardcoded secrets in audit target (Static Analyst grep + Adversarial Tester gadget chain hypothesis)
- Crypto weakness (weak hashing, missing TLS enforcement, insecure RNG)
- SSRF via outbound URL params (Static Analyst + Adversarial Tester)
- Missing CSP / `nosniff` / `Referrer-Policy` (Defensive Auditor walking served headers)

## What the quorum WILL NOT catch reliably

- Runtime business-logic abuse (race conditions, TOCTOU, payment-flow manipulation) — needs targeted threat modelling, not static + payload-hypothesis review.
- Insider-attack scenarios — relies on assumed-untrusted-input model; admin-side abuse needs separate analysis.
- Cross-tenant data leakage in multi-tenant deployments — context the quorum doesn't see unless explicitly given as audit_target.
- Architectural / design-level security flaws — covered by `team_security` 21-agent quorum at release sign-off, not by per-plan gate.

## Cross-cutting integration

The 3 specialists each consult sibling playbooks during their work:

- All three use `mcp__pb-codegraph__impact` for indirect-caller chase (codegraph.md is authoritative on what callers exist).
- All three use `mcp__graphiti__search_memory_facts` for prior incident recall (graphiti.md is authoritative on history).
- After the quorum verdict, `security-quorum` writes ONE episode to graphiti documenting the outcome under `<project>` group — future audits' Static Analyst recall surfaces it.

When a vulnerability is found, the report cites the codegraph impact result AND the graphiti incident match. That multi-source provenance is the point of the wire — each playbook contributes its angle.

## Failure modes (degrade gracefully, do not block on infrastructure)

| Infrastructure issue | Quorum response |
|---|---|
| codegraph unreachable | Specialists fall back to grep-only; mark `codegraph_reachable: false` in their JSON; quorum verdict includes the limitation in the report. NOT a vote-driving failure. |
| graphiti unreachable | Specialists skip prior-incident recall; mark `graphiti_reachable: false`; verdict episode write at the end is skipped (orchestrator surfaces this in the report). |
| One specialist agent returns malformed JSON | Orchestrator re-prompts that agent once; if still malformed, marks vote as MALFORMED and proceeds with 2-agent verdict (must be unanimous in that case). |
| All three specialists time out | Quorum reports NEEDS-REVIEW with escalation flag; do NOT default to PASS. |

## Re-running after fixes

After a FAIL verdict, the user addresses critical findings and re-runs the quorum on the same audit_target. The graphiti episode from the prior run surfaces in the Static Analyst's recall — the report should show "prior verdict was FAIL on these findings; current verdict is PASS — fixes confirmed at file:line".

If the user is iterating multiple times, cap at 3 quorum runs per ticket to avoid runaway cost. After that, escalate to `team_security` for a deeper look.

## Dependency & static-analysis intel (AP-5, 2026-08-03)

Automated intel that augments the human-style quorum — you review *our code*;
these scan what we depend on and known-bad patterns:

### composer audit — known-CVE check (plan time)

A daily monitor job (`dep-audit.sh`, central skills) already watches every
in-scope project and posts a chatroom escalation on NEW advisories — so at plan
time your question is just "is anything open right now?":

```bash
composer audit --locked        # in-container; host may lack private-repo auth
```

- A plan touching a package with an open advisory MUST say so and prefer the
  patched version as part of the work.
- CVEs are news, not gate-failures: an advisory appearing is never a reason to
  block a commit — it is a reason to schedule the bump.

### semgrep — SAST pass (security-sensitive diffs)

Installed on the HOST (`~/.local/bin/semgrep`, venv-backed; not in containers —
run host-side). For changes touching input handling, auth, SQL, file paths,
serialization, crypto, or anything a quorum would care about:

```bash
semgrep --config p/php --config p/security-audit --metrics=off --quiet <changed-dirs>
```

- Fast (~6s over all of app/code/Uptactics on pps) — scan the module, not one file.
- Findings are leads, not verdicts: verify each against the actual code path,
  cite file:line, and fold confirmed ones into the quorum's findings with rule
  id provenance.
- Quorum specialists SHOULD run this as their static sweep opener; zero
  findings is worth stating in the report ("semgrep p/php+p/security-audit
  clean") as coverage evidence.
