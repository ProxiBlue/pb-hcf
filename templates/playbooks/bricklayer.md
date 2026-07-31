# Bricklayer Runtime-Introspection Integration

This project runs the `inchoo/magento-bricklayer` MCP server — it boots the real Magento application and answers **what actually resolves at runtime with every enabled extension loaded**. Use it for any task where the truth depends on the merged, running state (resolved DI preference, ordered plugin chain, live observers, EAV as configured, error triage) rather than on what the source *looks like* it should do.

## Authority scope

This playbook is the source of truth for:
- **Runtime-resolved DI** — which class a preference/interface *actually* resolves to right now, across all modules (`di-configuration`, `preference-list`).
- **Merged plugin chains** — every plugin on a method, in real `sortOrder`, from all vendors (`plugin-list`, `check-class`).
- **Live EAV state** — all product/customer attributes including DB-only ones not in any XML (`eav-attributes`).
- **Actual DB schema** — real table structure as installed, before writing `db_schema.xml` (`database-schema`).
- **Runtime error triage** — combined log + DI + plugin analysis of a real exception (`diagnose-error`).
- **In-context execution** — running PHP inside the booted app to confirm behaviour (`code-runner`).

This playbook is NOT the authority for (defer to sibling playbooks):
- **Static structure / blast radius across the whole codebase incl. disabled modules + tests** → `codegraph.md` (fast static graph; sees code bricklayer can't boot).
- **What was discussed / decided / planned** → `graphiti.md` (intent, not runtime).
- **Security audit / vulnerability assessment** → `security.md`.
- **End-to-end test design / coverage** → `testing.md`.

### Bricklayer vs pb-codegraph — arbitration

They are complementary, not redundant:

| Question | Reach for |
|---|---|
| "What *fires / resolves* at runtime in THIS env?" | **bricklayer** — live boot, no snapshot drift, but only **enabled** modules + this env's config |
| "What could break structurally / full blast radius across all source (incl. disabled modules, tests)?" | **codegraph** — fast static graph over the whole tree |
| "Who calls X?" (structural) | codegraph `impact` |
| "Does my plugin actually land in the chain, at what order?" (runtime) | bricklayer `plugin-list` / `check-class` |

When the two **disagree on a resolution question, trust bricklayer** — it reads the booted app, codegraph reads a possibly-stale snapshot and cannot see env-specific module enablement or config. Cross-cite both; name the tool that produced the evidence.

## MCP server: `bricklayer`

Launched by a project-mounted gated wrapper (e.g. `.claude/scripts/bricklayer-mcp.sh`) — it runs `vendor/bin/bricklayer mcp` (installed in this project's `vendor/`). Tools called as `mcp__bricklayer__<name>`. 84 tools total; 17 Tier-1 essentials visible at startup, the rest discoverable via `search-tools`.

**Tier-1 essentials (the check→learn→write workflow):**

- **`check-class`** — combined plugins + DI + preferences for any class. The single best pre-check before touching a Magento class.
- **`application-info`** — Magento/PHP version, deploy mode, store hierarchy. Cheapest first-probe; confirms the app booted.
- **`di-configuration`** — runtime-resolved DI config from all modules. Check BEFORE modifying DI.
- **`plugin-list`** — existing plugins with `sortOrder`. Check BEFORE writing a plugin.
- **`preference-list`** — all preferences (rewrites). Check BEFORE overriding a class.
- **`eav-attributes`** — all attributes incl. DB-only. Check BEFORE working with product/customer data.
- **`database-schema`** — actual table structure. Check BEFORE writing `db_schema.xml`.
- **`database-query`** — read-only SELECT execution.
- **`diagnose-error`** — FIRST STEP for any error; combines logs + DI + plugin analysis.
- **`development-context`** — load coding guidelines BEFORE writing code (returns `_next_steps` pointing at the introspection tools to run next).
- **`code-runner`** / **`code-runner-help`** — execute PHP in Magento context.
- **`product-get`** / **`order-get`** / **`customer-get`** — fetch by SKU / increment ID / email.
- **`search-tools`** — discover the other 67 tools by keyword.
- **`batch-execute`** — run multiple tools in one call.

Introspection tools return `_skill_hint` / `_next_steps` — follow them; they encode the intended check→learn→write path.

## Reachability — check before use

First-probe with `application-info`:

- **Tools present, `application-info` returns version/deploy-mode** → good, proceed.
- **No `mcp__bricklayer__*` tools exist / server exited** → the gated wrapper found no `vendor/bin/bricklayer`. Reinstall (inside the project's dev container):
  ```bash
  composer require --dev inchoo/magento-bricklayer
  vendor/bin/bricklayer install --env=ddev --agents=claude-code
  ```
  Then restart the Claude session so the MCP re-launches. Until then, **do not silently pretend runtime data**; state that bricklayer is unavailable and fall back to `codegraph.md` (static) + reading source, noting the analysis is structural-only.

## Devil's Advocate playbook (HCF plan review) — primary consumer

When `devils-advocate` reviews a plan, bricklayer closes the exact gap codegraph leaves open: codegraph enumerates *possible* wiring from a static snapshot; bricklayer reads the *resolved* runtime truth. Its checklist items 2 (framework gotchas) and 6 (integration completeness) are strongest here.

1. **For every class the plan plugins / overrides / modifies** — `check-class`. If a **DI preference already substitutes a different class** for the plan's target, a plugin/preference planned against the original **never fires** → flag **Critical**, quote the `preference-list` / `di-configuration` result.
2. **For every plugin the plan adds** — `plugin-list` on the target method. If existing third-party plugins occupy conflicting `sortOrder`, or the plan's assumed order is wrong, flag **Important** with the resolved chain listed.
3. **For every observer / event the plan touches** — confirm what already observes it at runtime (via `check-class` / `search-tools event`). Existing vendor observers frequently collide.
4. **For any product/customer data work** — `eav-attributes` to confirm the attribute exists and its backend type, before the plan assumes a column.
5. **Limitation:** bricklayer sees only **currently enabled** modules in **this env**. Code the plan *adds*, or logic in *disabled* modules, is invisible — note that in `_devils_advocate.md` and defer the static half to codegraph.

Cite the bricklayer tool + class that produced each finding (e.g. *"`preference-list` shows `Magento\...\ProductRepositoryInterface` resolves to `VendorZ\Module\Repository`; the plan's plugin targets the core class and will not run"*).

## TDD Worker playbook (HCF implementation)

Before modifying any class:
- `check-class` on the target — one call surfaces the plugins, DI, and preferences you must respect.
- `development-context category=<plugin|di|observer|...>` — load the guideline, then follow its `_next_steps`.

For new DI / plugins / observers / preferences:
- `di-configuration` / `plugin-list` / `preference-list` on the target BEFORE writing. Decide consciously: stack the plugin, replace the preference, or extend the observer.

Verification (after `setup:di:compile`):
- Re-run `plugin-list` / `check-class` → confirm the new plugin actually appears in the chain at the intended `sortOrder`, with all vendors loaded.
- `diagnose-error` on any exception surfaced during red→green — it correlates the log with DI/plugin state instead of guessing.
- `code-runner` to exercise the resolved behaviour in-context when a test can't easily reach it.

## Plan Create (HCF design)

Before writing tasks, enumerate the real interception surface on the target — `check-class` + `plugin-list` + `preference-list` — so tasks aim at the correct, currently-winning class from the start rather than a core class a vendor has already displaced.

## When NOT to use bricklayer

- Pure template / CSS / copy edits — no runtime resolution involved.
- Static "who calls X across the entire codebase" / blast radius → `codegraph.md` is faster and covers disabled modules + tests.
- When the app cannot boot (broken build, mid-migration DB) — bricklayer needs a working Magento; fall back to codegraph + source and say so.
- Writes to catalog/order/customer data on anything but a throwaway env — treat CRUD tools as capable of mutating real data; default to read-only introspection.
