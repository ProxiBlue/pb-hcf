# GitNexus Code-Graph Integration

This project has a pre-built GitNexus knowledge graph reachable over MCP at `gitnexus:4747`. Use it for any task requiring code-graph queries — finding callers, dependents, signatures, or Magento framework wiring — that would otherwise rely on shallow grep and miss indirect references.

## Authority scope

This playbook is the source of truth for:
- **Code structure** — classes, methods, signatures present in the current index.
- **Caller / dependent enumeration** — who calls what; who is called by what; blast radius of a change.
- **Magento indirect wiring** — plugins, observers, DI preferences, layout XML hooks that grep misses.
- **Symbol-level impact analysis** — "what breaks if I change X".

This playbook is NOT the authority for (defer to sibling playbooks):
- **What was discussed / decided / planned about a piece of code** → `graphiti.md` (intent lives there, not in the AST).
- **Security audit / vulnerability assessment** → `security.md` (when wired).
- **End-to-end test design / coverage** → `playwright.md` / `testing.md` (when wired).

When a question could be answered by GitNexus OR a sibling playbook's tool, reach for both. Cite the tool that produced the evidence. GitNexus is authoritative when the question is structural; defer to others when the question is intent or risk.

## MCP server: `gitnexus-mageos`

Available tools (called as `mcp__gitnexus-mageos__<name>`):

- **`list_repos`** [read-only] — list all indexed repositories available to GitNexus. Cheapest first-probe call; confirms the index is loaded and shows which repos (`mageos`, `hyva`, `deps`, …) are queryable. Always call this once at the start of any gitnexus-using task.
- **`find_symbol`** — locate a class / method / function by name; returns file path + signature. Use to confirm a symbol exists and matches the signature the plan assumes.
- **`impact`** — enumerate everything that depends on or is depended-on by a given symbol (full blast radius, includes indirect callers via plugins / observers / DI preferences). Use to find missing affected code.
- **`query`** — run Cypher-like graph queries (advanced). Use when `find_symbol` / `impact` aren't expressive enough.
- **`context`** — pull surrounding code context for a symbol.

The index spans **mageos core + hyva + deps** with reciprocal-rank-fusion ranking. Set `repo` to `@mageos-project` for federated search across all three (default behaviour).

## Reachability — check before use

Before any gitnexus call, verify the per-project gitnexus service is reachable from inside the DDEV web container:

```bash
curl -sS -o /dev/null -w 'HTTP %{http_code}\n' -m 3 http://gitnexus:4747/
```

Expect `HTTP 200`. If the container is down (`curl: (7) Failed to connect` or non-200), **do not silently fall back** — explicitly state in your output that gitnexus is unreachable so the user knows the analysis is shallower than usual, then proceed with Grep-only. The gitnexus service is wired via this project's `.ddev/docker-compose.gitnexus.yaml`; if it's not coming up, suggest `ddev restart`, then `ddev logs gitnexus` to inspect.

After curl reports 200, also call `mcp__gitnexus-mageos__list_repos` once — this confirms the index is actually loaded (not just the HTTP port answering) and reveals which repos the server has available. If `list_repos` returns empty or errors out, the container is up but the index didn't load; flag this and stop.

## Devil's Advocate playbook (HCF plan review)

When the `devils-advocate` agent reviews a plan (`_plan.md` + task files), the existing prompt's checklist items 1 (missing dependencies between tasks), 2 (framework gotchas), and 6 (integration completeness) are exactly where grep-only analysis is weakest on Magento. GitNexus closes the gap:

1. **For every class / method / function named in any task file or `_plan.md`** — call `find_symbol`. If the symbol does not exist, or its visibility / signature does not match what the task assumes, flag as **Critical** with the gitnexus result quoted.
2. **For every method the plan modifies, replaces, overrides, or plugins** — call `impact`. Cross-reference the returned caller list against the plan's task scope. Any caller NOT covered by a task is a **Critical** missing dependency. Pay particular attention to:
   - Plugins (`Magento\Framework\Interception` chains) — `impact` surfaces them, grep misses them.
   - Observers — wired via `events.xml`, often in unrelated modules.
   - DI preferences — a different class may already be substituted in for the one the plan targets.
3. **For every new Magento wiring point the plan adds** (`di.xml` plugin / preference, `events.xml` observer) — query the graph for existing wiring on the same target. Existing third-party-module wiring frequently collides with the planned one; flag as **Important** with both wirings listed.
4. **For new code the plan introduces** — gitnexus cannot see it (index is a snapshot of existing code). Note this limitation explicitly in `_devils_advocate.md` so the reviewer knows the forward-reference half is unverified.

In `_devils_advocate.md`, every finding citing graph evidence should reference the gitnexus tool + symbol that produced it (e.g., *"`impact` on `Magento\Quote\Model\Quote::collectTotals` returns 14 callers; tasks 003–005 cover only 6"*). Empty findings on a class that should clearly have callers is a red flag — re-run the reachability check and verify the symbol name.

## TDD Worker playbook (HCF implementation)

Before modifying any class:
- `find_symbol` on the class to confirm signature.
- `impact` on any public method being changed → list of tests / callers to verify or update.

For new Magento DI / plugins / observers / preferences:
- Query the graph for existing wiring on the same target before writing the new module. If wiring already exists, decide consciously: stack the plugin, replace the preference, or extend the observer.

## Standards Enforcer / other agents

When asked "is X used anywhere?" — `impact` is authoritative; grep is not. Cite the tool used.

## Federated search

The merged index covers three sources:

- `repo=mageos` — Mage-OS core
- `repo=hyva` — Hyva theme + storefront
- `repo=deps` — third-party modules under `vendor/`
- omit `repo` → federated across all three (default, RRF-ranked)

For "where is this used across everything", use federated. For "find this in core only", narrow to `mageos`.

## When NOT to use gitnexus

- Pure file-content edits where signature / caller info is irrelevant (template tweaks, CSS, copy changes).
- Anything under `pub/`, `var/`, `generated/` — runtime artefacts, excluded from index.
- Test files — index is source-only.
- New code being added in-flight (not yet indexed).

## Index freshness

The index is a snapshot; it does not auto-rebuild on file change. If the project has had structural changes since the last `gitnexus publish`, results may be stale. When a `find_symbol` / `impact` result conflicts with what's currently in the source files, **trust the source files** and note the index drift in your output.
