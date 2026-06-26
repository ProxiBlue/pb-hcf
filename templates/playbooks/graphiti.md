# Graphiti Knowledge-Graph Integration

This project is wired into the fleet-wide Graphiti knowledge graph reachable over MCP at `http://localhost:8765/mcp` (host) or `http://host.docker.internal:8765/mcp` (DDEV container). Use it for any task that benefits from prior **discussions, decisions, incidents, vendor verdicts, or planned-but-not-built work** — the kind of context that lives in emails, tickets, ADRs, and past consolidations, not in the codebase.

## Authority scope

This playbook is the source of truth for:
- **What was discussed / decided / promised / planned / failed.** Intent and history.
- **Temporal questions** ("what changed since…", "what was decided before…").
- **Cross-source recall** spanning emails, tickets, docs, and past sessions.
- **Vendor / client / domain knowledge** captured via ingest channels.

This playbook is NOT the authority for (defer to sibling playbooks):
- **Code structure / callers / impact** → `gitnexus.md` (GitNexus is authoritative for current code reach).
- **Security audit / OWASP / vulnerability assessment** → `security.md` (when wired).
- **End-to-end test design / coverage** → `playwright.md` / `testing.md` (when wired).

When a question could be answered by Graphiti OR a sibling playbook's tool, reach for both. Cite the tool that produced the evidence. Graphiti facts carry added weight when they reference deferred / planned work — that's the unique value.

## MCP server: `graphiti`

Available tools (called as `mcp__graphiti__<name>`):

- **`get_status`** [read-only] — cheap probe; confirms the MCP server is reachable and connected to Neo4j. Call once at the start of any graphiti-using task.
- **`search_nodes`** — semantic + keyword + graph search over entities (`Vendor`, `Decision`, `Incident`, `Project`, `Procedure`, `Topic`, `Preference`, `Client`, `Component`). Filter by `entity_types`. Re-rank around a `center_node_uuid` for relatedness. Free of LLM cost (embedding-based).
- **`search_memory_facts`** — search over facts/edges (relationships between entities). Returns triples with rich context. Filter by edge type and bi-temporal `valid_at` / `invalid_at` date ranges.
- **`get_episodes`** — fetch raw episode bodies for a group_id. Useful for `initial_ingest` (always-loaded pinned facts).
- **`get_entity_edge` / `get_episode_entities`** — provenance: trace a fact back to its source episode and entities.
- **`add_memory`** — write a new episode. **Bound by Hard Rule 1** (`pb-graphiti:graphiti-usage` SKILL.md) — classify and confirm scope with the user before each mid-conversation write. Hook contexts (PreCompact / SessionEnd / TaskCompleted / SubagentStop) bypass this rule and auto-write.

## Reachability — check before use

Before any graphiti call, verify the MCP server is up:

```bash
# from host
curl -sS -o /dev/null -w 'HTTP %{http_code}\n' -m 3 http://localhost:8765/mcp
# from DDEV container
curl -sS -o /dev/null -w 'HTTP %{http_code}\n' -m 3 http://host.docker.internal:8765/mcp
```

Expect `307` (the server redirects `/mcp/` → `/mcp` — that's the healthy response, NOT a failure). If unreachable, call `mcp__graphiti__get_status` once for a definitive answer.

If the server is down, **do not silently fall back**. State explicitly that graphiti is unreachable and that the analysis lacks discussion / decision context. Suggest the user check `docker logs --since 5m graphiti-mcp` and `docker logs graphiti-neo4j` (see the graphiti-fleet stack's README for the docker-compose location). Proceed with code-only analysis (gitnexus + grep) but flag the gap.

## Group model — query both project AND fleet

Every fact has a `group_id`:

- **`<project-id>`** — project-specific. Resolve by: `$DDEV_PROJECT` env var → `basename $(git rev-parse --show-toplevel)`. Per-project quirks, LIVE branch, project-only conventions, per-client preferences.
- **`fleet`** — TRUE cross-project methodology. Vendor verdicts applying everywhere, organisation-wide rules, tool-use conventions ALL projects follow.
- **`host`** — host-side agent ops (pb-graphiti plugin internals, fleet-mgmt scripts). Almost never relevant inside a project session — skip unless a host-ops question.

**For every search, pass `group_ids=[<project-id>, "fleet"]`.** Project alone misses fleet methodology; fleet alone misses project-specific decisions. Both together is the discipline.

For writes from a project session: default to `<project-id>`. Only use `fleet` if the fact would be valuable in an unrelated client project tomorrow.

## Plan-Create playbook (HCF `/hcf:plan-create`)

Plan-creation is where graphiti has the highest leverage. Before drafting `_plan.md`:

### Phase 1 — Discovery enrichment (before codebase glob)

Extract 3-6 key nouns + verbs from the feature description. For each, run two cheap parallel queries:

```
search_nodes(group_ids=[<project>, "fleet"],
             entity_types=["Decision","Incident","Project","Topic","Vendor"],
             query="<noun>", max_nodes=5)
search_memory_facts(group_ids=[<project>, "fleet"],
                    query="<noun>", max_facts=5)
```

Synthesise findings into a `## Historical & Related Context` preamble injected into the plan input. Categorise:

- **Discussed but not yet built** — search results where the source is an email thread (`source_description STARTS WITH "mid:"`) or a ticket (`https://github.com/...`) mentioning planned / queued / future / upcoming / "we should also" work in the same domain. **This is the highest-value signal** — design the current plan to integrate with planned-adjacent work.
- **Past decisions in this domain** — `Decision` entities. Surface the rationale so the plan doesn't unknowingly contradict prior architecture choices.
- **Past incidents in this area** — `Incident` entities. Add risk callouts to the plan's `## Risks & Mitigations`.
- **Vendor / integration constraints** — `Vendor` entities with verdicts that limit design space (e.g., "Stripe blocked for AU customers", "Cliniko rate-limit constraints").
- **Client preferences** — `Preference` or `Client` entities. Influence scope decisions silently if not surfaced.

Triage: drop noise (single mentions, no cited rationale, results older than 18 months unless they're explicit policy). Aim for 3-10 high-signal items in the preamble, not a 50-row dump.

### Phase 3 — Scope refinement

When narrowing in / out scope, re-query graphiti with the now-specific scope language. Look for facts that say *"this kind of feature historically requires X"* — surface as scope-relevant context to the user during clarification.

### After plan drafted (post-Phase 3)

Check the planned approach against `search_memory_facts(query="<planned approach summary>")`. Specifically look for **conflicts** — facts saying "we tried this approach and it failed because…". Flag as `## Risks & Mitigations` items with the cited episode.

## Devil's Advocate playbook (HCF plan review)

When devils-advocate reviews a plan, in addition to its existing gitnexus-aware checks, query graphiti for:

1. **Adjacent planned work that may conflict or synergise** — `search_memory_facts(group_ids=[<project>, "fleet"], query="<plan title + key nouns>")`. Surface deferred features in the same domain. If the current plan should integrate with one, flag as **Important**; if it would block one, flag as **Critical**.
2. **Past incidents this plan might repeat** — `search_nodes(entity_types=["Incident"], query="<plan domain>")`. If a prior incident's root cause matches the plan's approach, flag as **Critical** with the incident citation.
3. **Vendor verdicts the plan implicitly violates** — `search_nodes(entity_types=["Vendor"], query="<vendors named in plan>")`. If the plan integrates a vendor we've previously blocked or constrained, flag as **Critical**.
4. **Client preferences the plan ignores** — `search_nodes(entity_types=["Preference","Client"], query="<client + domain>")`. Per-client conventions that the plan should respect.

Every graphiti-cited finding in `_devils_advocate.md` should reference the tool + episode (e.g. *"`search_memory_facts` returned 'Future invoicing flow proposal' from email thread mid:abc123 dated 2026-05-15 — this plan's payment-method enum conflicts with that proposal's discriminator field"*).

## TDD Worker playbook

Before implementing a task, query graphiti for:

- **Prior incidents in the same area** — `search_memory_facts(query="<task subject>")` filtered for `Incident` source. Apply the fix or guard learned.
- **Runbook steps for this kind of work** — `search_nodes(entity_types=["Procedure"], query="<task subject>")`. Apply established sequencing.

Do NOT write to graphiti from inside the worker for routine implementations — the worker's output IS the diff + tests, that's already provenance. Only call `add_memory` (with Hard Rule 1 scope-confirm) if the worker uncovered a non-obvious blocker or design pivot that future workers should know about.

## Standards Enforcer / other agents

When asked "is convention X followed here?" — `search_nodes(entity_types=["Decision","Preference"], query="<convention>")` answers whether the convention was explicitly chosen or rejected for this project / fleet. Cite the result. Without it, "convention" is just opinion.

## Bi-temporal model — `valid_at` vs `created_at`

Episodic nodes carry TWO times:
- `created_at` — when graphiti ingested the episode
- `valid_at` — when the described event actually occurred (set from email Date header, ticket created_at, file mtime, etc.)

For time-sensitive queries, filter on `valid_at`. Example: *"what was decided about payment flow in Q2 2026?"* → cypher with `WHERE ep.valid_at >= datetime("2026-04-01") AND ep.valid_at < datetime("2026-07-01")`.

`reference_time` is the MCP API parameter; on the node itself the field is named `valid_at`. (`ep.reference_time` returns null on Episodic — that's a property-name mismatch, NOT missing data.)

## Source / citation patterns

| Prefix on `source_description` | Origin |
|---|---|
| `mid:<message-id>` | Email ingest (Zoho / Gmail) |
| `https://github.com/.../issues/N` or `.../pull/N` | GitHub ticket ingest |
| `file:///var/www/html/...` | Folder doc ingest |
| `slack://channel/<id>/<ts>` | Slack export ingest |
| `claude-code-session://<sid> [precompact ...]` | PreCompact hook write |
| `claude-code-session://<sid> [session-end ...]` | SessionEnd hook write |
| `claude-code-session://<sid> [task-completed ...]` | TaskCompleted hook write |
| `claude-code-session://<sid> [subagent-stop ...]` | SubagentStop hook write |
| `claude-code-conversation://<sid> [add_memory ...]` | Mid-conversation manual save |

Useful for filtering: *"only show me decisions that came from email discussions"* → filter `source_description STARTS WITH "mid:"` in a cypher follow-up.

## When NOT to use graphiti

- **Code structure questions** — "who calls Quote::collectTotals" → use `mcp__gitnexus-mageos__impact`, not graphiti. Graphiti has Component nodes but they're noise-prone (NPM packages, file paths). GitNexus is the authoritative structural index.
- **Current file state** — graphiti's facts are point-in-time; the source file may have moved on. Trust the source for current code; trust graphiti for "what was discussed when".
- **Pure documentation lookups** — read the doc directly. Graphiti recall is for "what's our institutional memory on this" not "what does this README say".
- **High-frequency in-loop queries** — searches are cheap but not free; don't call graphiti from inside a per-file-edit loop. Hoist queries to task-boundary level.

## Cost awareness

- All read tools (`search_nodes`, `search_memory_facts`, `get_episodes`, `get_status`) are essentially free — embedding + graph traversal, no LLM. Query liberally during planning + review.
- `add_memory` is NOT free — each write spawns LLM-backed entity extraction (~$0.005-0.02 per episode on Haiku 4.5). Cap mid-conversation writes per Hard Rule 1; let the hooks handle bulk consolidation.
- Hook fires (SessionEnd / SubagentStop) are budgeted by their own per-hook caps in `pb-graphiti/hooks/hooks.json`. Do not invoke them manually.

## Graph freshness

Episodes are written as ingest fires (email cron daily, ticket cron every 6h, folder ingest on-demand, session hooks on session-end). The graph reflects whatever has been ingested up to now — if a recent email thread isn't surfacing, run the cron manually or wait for the next scheduled run. Use `get_status` + a `MATCH (ep:Episodic) RETURN max(ep.created_at)` cypher (via the log-viewer dashboard at http://localhost:7475 or Neo4j Browser at :7474) to confirm freshness when results feel thin.
