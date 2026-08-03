# bugsink — production & runtime error context

**Authority scope:** observed runtime errors. When a plan or change touches an
area of the code, consult this to learn what is *actually breaking* there — in
production and during dev/build runs. Static analysis sees structure; the test
suite sees asserted behaviour; this sees the failures real traffic produced.
(Post-batch *verification* of new errors is the `issue-sentinel` agent's job —
this playbook is the plan-time read.)

Bugsink is the central host-level error tracker (Sentry-compatible, one
instance, one Bugsink project per site/context). Query it over REST:

```bash
source ~/.pb-hcf/bugsink.env   # BUGSINK_URL_HOST, BUGSINK_URL_CONTAINER, BUGSINK_API_TOKEN
# In a ddev container use $BUGSINK_URL_CONTAINER; on the host $BUGSINK_URL_HOST.
BS="$BUGSINK_URL_CONTAINER"    # or _HOST
```

If the env file is missing/unreadable where you run, say so and skip — never
guess at error state.

## Query 1 — what's breaking in this project (the first question, always)

```bash
curl -s -H "Authorization: Bearer $BUGSINK_API_TOKEN" \
  "$BS/api/canonical/0/issues/?project=<id>" | jq -r '.results[]
    | [.friendly_id, .calculated_type, .calculated_value[:60],
       .last_seen[:10], .digested_event_count, (.is_resolved|tostring)]
    | @tsv'
```

Project ids: list them with `GET /api/canonical/0/projects/`. Convention: one
project per context — e.g. `pps` (ddev/build errors) vs `pps-prod` (production
feed). **Plan-time questions are usually about the `-prod` project.**

## Query 2 — errors touching the plan's area

The issue list carries `calculated_type` (exception class), `calculated_value`
(message), `transaction`, and `last_frame_filename` / `last_frame_function`.
Filter client-side for the files/modules the plan touches:

```bash
curl -s -H "Authorization: Bearer $BUGSINK_API_TOKEN" \
  "$BS/api/canonical/0/issues/?project=<id>" \
  | jq -r '.results[] | select((.last_frame_filename // "")
      | test("Uptactics|checkout|quote"; "i"))
    | [.friendly_id, .calculated_type, .last_frame_filename] | @tsv'
```

An unresolved issue whose last frame is in a file the plan modifies is a
**must-mention** in the plan — either the plan fixes it or explains why not.

## Query 3 — event detail / stacktrace for one issue

```bash
curl -s -H "Authorization: Bearer $BUGSINK_API_TOKEN" \
  "$BS/api/canonical/0/events/?issue=<issue-uuid>" | jq '.results[0]'
```

Gives the full Sentry-shaped event: exception chain, frames, tags (environment,
release), timestamp. Cite `file:line` from the top in-app frame, not the
framework frames.

## Query 4 — is it getting worse / did it come back

`digested_event_count` + `first_seen`/`last_seen` on the issue answer trend
questions. An issue with `is_resolved: true` but a `last_seen` after its fix
date is a **regression** — flag it with both timestamps.

## How to use it in the HCF loop

- **pre-plan:** run Query 1 + 2 for the touched area on the `-prod` project.
  Open issues in that area go into the plan with their `friendly_id` — a plan
  touching code that's actively throwing in production must say so.
- **post-implementation / post-batch:** that's `issue-sentinel` (enrolled via
  `/pb-hcf:wire --enable=issue-sentinel`) — don't duplicate its marker-scoped
  query here.

Keep it proportionate: Query 1 is the standing habit; 2–4 when the area is hot
or an issue matches the diff.
