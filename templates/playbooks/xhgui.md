# xhgui Runtime-Performance Integration

This project captures xhprof request profiles into an xhgui trace store queryable over plain SQL. Use it whenever a plan or change touches a page or flow's *speed, memory, or query count* — it gives you observed runtime cost, which static analysis (code graph, grep) cannot see.

## Authority scope

This playbook is the source of truth for:
- **Runtime cost of a URL/flow** — wall time, CPU, memory, trend over time.
- **Function hotspots** — which functions dominate a slow page, observed rather than inferred.
- **SQL query counts per request** — the number Magento performance usually turns on.
- **Perf regression verdicts** — before/after compare and the opt-in commit gate.

It defers to siblings:
- Static structure, callers, blast radius of a change → `codegraph.md`.
- Runtime-resolved DI preferences / merged plugin chains (why THIS code runs) → `bricklayer.md`.
- Runtime errors and exceptions → `bugsink.md`.
- Production data scale (dev DB lies about row counts) → `prod-shape.md`.

## Where the data lives

xhgui profiles requests and stores them in the MySQL table **`xhgui.results`** on
the project DB server. Query it with your **database MCP**, or — if the MCP is
scoped to the app DB only — with `mysql -hdb -uroot -proot xhgui -e "<sql>"`
in-container (or `ddev mysql -uroot -proot xhgui -e "<sql>"` from the host). No
special tool; it's just SQL against the `xhgui` database.

## Enable capture (if `xhgui.results` is empty)

```
ddev xhprof on          # xhprof_mode: xhgui — profiles into xhgui.results
ddev xhgui              # (optional) the web UI; not needed to query
```
Then exercise the page(s) you care about (browse the site, or drive with
Playwright) so traces accrue. xhprof has a runtime cost — turn it `off` when done.

## Query 1 — how slow is a URL (the first question, always)

Flat aggregate columns; works on any MySQL/MariaDB:
```sql
SELECT simple_url,
       ROUND(AVG(main_wt)/1000,1)      AS avg_wall_ms,
       ROUND(MAX(main_wt)/1000,1)      AS max_wall_ms,
       ROUND(AVG(main_mu)/1048576,1)   AS avg_mem_mb,
       COUNT(*)                        AS traces
FROM xhgui.results
WHERE simple_url LIKE '%<path>%'
GROUP BY simple_url
ORDER BY avg_wall_ms DESC
LIMIT 10;
```
Columns: `main_wt` = wall time µs, `main_cpu` = cpu µs, `main_mu`/`main_pmu` =
memory / peak memory bytes, `main_ct` = total function calls, `request_ts` = unix
time. Divide wt/cpu by 1000 for ms, mu by 1048576 for MB.

## Query 2 — recent trend for a URL (did it change over time)

```sql
SELECT FROM_UNIXTIME(request_ts) AS t, ROUND(main_wt/1000,1) AS wall_ms,
       ROUND(main_mu/1048576,1) AS mem_mb
FROM xhgui.results
WHERE simple_url = '<exact simple_url>'
ORDER BY request_ts DESC LIMIT 20;
```

## Query 3 — top functions / hotspots for a slow URL

The per-function profile is in the `profile` longtext (xhprof JSON, keyed
`caller==>callee` with `{ct,wt,cpu,mu,pmu}`). MariaDB 10.5 has no `JSON_TABLE`,
so **fetch the profile and parse it yourself**:
```sql
SELECT id, profile FROM xhgui.results
WHERE simple_url = '<url>' ORDER BY main_wt DESC LIMIT 1;
```
Then, from the JSON, aggregate `wt` by *callee* (the part after `==>`) and rank —
the top callees by summed `wt` are the hot functions. Same aggregation on the
`ct` of callees named like `PDO::exec*`, `mysqli*::query`, `Zend_Db_*` gives the
**SQL query count** — the number Magento performance usually turns on.

## Query 4 — before/after regression compare (build time)

You can eyeball it in SQL — newest traces are "after", older are "before":
```sql
SELECT id, request_ts, ROUND(main_wt/1000,1) AS wall_ms
FROM xhgui.results
WHERE simple_url = '<url>' ORDER BY request_ts DESC LIMIT 6;
```
But for a deterministic answer use the **engine**, `scripts/perf-compare.sh`
(central skills `scripts/` dir), which snapshots a baseline (a watermark + avg
wall time) and then compares only traces recorded *after* it:
```
perf-compare.sh save-baseline <url-substr>   # BEFORE the change, page already warm
# ... make the change, then re-exercise the page so fresh traces land ...
perf-compare.sh check        <url-substr>    # exit 1 = regression, with %; 3 = no after-data
```
It gates on **wall time** only — the one reliable flat column. (`main_ct` is NOT
total call count; it is `main()`'s own count, always 1 — do not use it. For the
query count behind a slowdown, parse the profile JSON per Query 3; that stays a
judgement call for the reviewer, not a hard gate.)

**Cache caveat (this bites):** baseline and "after" must be captured under
comparable cache state. A cold-cache "after" against a warm baseline shows a huge
false regression (observed live: 291ms → 1738ms purely from cold FPC/config
cache). Warm the page (hit it once or twice) before both the baseline and the
re-profile.

## How to use it in the HCF loop

- **pre-plan:** for each URL/flow the plan will touch, run Query 1 (+ Query 3 if
  slow). If the plan modifies a function that's a top-10 hotspot, or adds DB
  calls to a URL that already has a high query count, say so **with the numbers**
  in the plan. A change to `Quote::collectTotals` and a change to a one-off admin
  action are not the same risk — this is how you tell them apart.
- **post-implementation:** re-trace the touched URL, run Query 4 (or
  `perf-compare.sh check`), and report any wall-time regression versus baseline
  with the numbers.
- **build-time gate (opt-in):** `perf-gate.sh` blocks a commit when a URL with a
  recorded baseline regresses on wall time beyond threshold. Arm it per project
  with `.claude/perf-gate.json` `{"enabled": true, "wall_pct": 25,
  "min_wall_ms": 100}` plus a saved `.claude/perf-baseline.json`. Fails OPEN when
  there's no post-baseline trace to compare — it only blocks on a *measured*
  regression, never on missing data.

Keep it proportionate: Query 1 on the touched URLs is the standing habit; Queries
3–4 + the gate are for when a page is slow or the change is perf-sensitive.
