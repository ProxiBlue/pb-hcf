# prod-shape — production data scale context

**Authority scope:** data scale. When a plan or change touches queries, loops,
indexers, exports, or anything whose cost grows with data volume, consult this —
the dev DB lies about scale, and this file carries the *production* numbers.

The shape lives at **`.claude/prod-shape.json`** (counts and distributions only —
never rows, never PII). It is captured by the **operator** running
`prod-shape-collect.sh` on the production host (central skills `scripts/` dir);
agents never touch production. Read it with the Read tool; no service involved.

## How to use it

1. **Check freshness first.** `captured` older than ~60 days → say
   "prod shape stale (captured <date>) — numbers may have drifted" and treat
   values as approximate. Missing file → say so; do NOT substitute dev-DB
   counts silently.
2. **Scale-check the plan's hot spots.** The classic traps:
   - `url_rewrite` — full-table operations that are instant on dev can be
     minutes on prod. Check `tables.url_rewrite`.
   - EAV bloat — `catalog_product_entity_varchar`/`_int` row counts tell you
     what an unbatched attribute walk really costs.
   - `distributions.max_children_per_configurable` — a PDP/listing change that
     loads all children chokes on the worst configurable, not the average one.
   - `distributions.products_per_category_p95` — category-page work must
     survive the p95 category, not the demo category.
   - `orders_per_month_avg_12m` × months = how fast `sales_order*` grows; sizes
     cron/report/export batch decisions.
   - `largest_tables` — third-party surprises (index/report tables) that
     dev-DB thinking misses entirely.
3. **Cite the number in the plan.** "url_rewrite has 1.2M rows on prod — this
   migration must batch" beats "should be careful with large tables".

## Refresh (operator, monthly-ish)

```bash
# on the production host (read-only aggregates, ~10s):
bash prod-shape-collect.sh <db-name> > prod-shape.json
# then place it at <project>/.claude/prod-shape.json on the workstation
```

## How to use it in the HCF loop

- **pre-plan:** for any plan touching data-volume-sensitive code, read the
  shape file and put the relevant numbers IN the plan. A plan that batches by
  500 because prod has 1.2M rewrites is a different plan from one that never
  looked.
- **devils-advocate / review:** challenge unbatched loops and unbounded loads
  against these numbers, not intuition.
