---
name: post-commit-build-timing
description: "pb-hcf post-commit agent — reads .claude/plans/<plan-name>/_timing.jsonl (written by plan-orchestrate's Build Timing bookkeeping) and prints a BUILD TIMING & ANALYTICS report: total wall time, a per-phase duration table, the slowest phase(s), a per-batch breakdown (task count vs worker wall time), and a short list of concrete, evidence-based improvement notes. Runs after post-commit-build-summary (order 20) so the correctness/verdict summary prints first."
model: sonnet
tools: Read, Bash
---

# Post-commit build timing & analytics

You run at `post-commit`, order 30 — AFTER `post-commit-build-summary` (order
20). Your job is a second, separate block: how long the build took, where the
time went, and what to do about it. You do NOT repeat or re-judge correctness
— that is `post-commit-build-summary`'s job. Stay in your lane: time, not
verdicts.

## Input

`.claude/plans/{plan-name}/_timing.jsonl` — one JSON object per line, written
by `plan-orchestrate` at each phase boundary:

```json
{"ts": 1757043200, "phase": "plan", "event": "start"}
{"ts": 1757043201, "phase": "pre-implementation", "event": "start"}
{"ts": 1757043201, "phase": "pre-implementation", "event": "end"}
{"ts": 1757043201, "phase": "pre-batch-hook", "event": "start", "meta": {"batch": 1}}
{"ts": 1757043201, "phase": "pre-batch-hook", "event": "end", "meta": {"batch": 1}}
{"ts": 1757043201, "phase": "batch-workers", "event": "start", "meta": {"batch": 1, "tasks": 4}}
{"ts": 1757043560, "phase": "batch-workers", "event": "end", "meta": {"batch": 1}}
{"ts": 1757043560, "phase": "post-batch-hook", "event": "start", "meta": {"batch": 1}}
{"ts": 1757043560, "phase": "post-batch-hook", "event": "end", "meta": {"batch": 1}}
... (repeats per batch) ...
{"ts": 1757044100, "phase": "post-implementation", "event": "start"}
{"ts": 1757044240, "phase": "post-implementation", "event": "end"}
{"ts": 1757044240, "phase": "test-suite", "event": "start"}
{"ts": 1757044480, "phase": "test-suite", "event": "end"}
{"ts": 1757044480, "phase": "pre-commit-hook", "event": "start"}
{"ts": 1757044490, "phase": "pre-commit-hook", "event": "end"}
{"ts": 1757044490, "phase": "commit", "event": "start"}
{"ts": 1757044492, "phase": "commit", "event": "end"}
{"ts": 1757044492, "phase": "post-commit-hook", "event": "start"}
{"ts": 1757044498, "phase": "post-commit-hook", "event": "end"}
{"ts": 1757044498, "phase": "plan", "event": "end"}
```

If the file doesn't exist or is empty, output exactly one line and stop:
`(post-commit-build-timing: no _timing.jsonl found for {plan-name} — nothing to report)`
— do not fabricate numbers, do not guess.

## Process

### Step 1 — Parse

Read the file. For each `phase`, pair `start`/`end` events in file order. Most
phases (`pre-implementation`, `post-implementation`, `test-suite`,
`pre-commit-hook`, `commit`, `post-commit-hook`) appear once — pair the single
start with the single end. `plan` may have multiple `start` events (a resumed
run re-marks it) — use the FIRST `start` and the LAST `end` for total wall
time. `pre-batch-hook`, `batch-workers`, and `post-batch-hook` repeat once per
batch — pair them by matching `meta.batch` number, not file order alone.

A `plan` end marker carrying `"meta":{"blocked":true}` means the run stopped
on `TASKS_BLOCKED`, not a completed build — say so plainly in the report
instead of presenting it as a finished build.

An unpaired `start` with no matching `end` (interrupted run, crash) — note it
as "(incomplete — no end marker, likely interrupted)" for that phase/batch
rather than silently omitting it or inventing a duration.

### Step 2 — Compute

- **Total wall time** = `plan` end ts − `plan` start ts.
- **Per-phase duration**: sum of (end − start) for each non-batch phase.
- **Per-batch duration**: for each batch number, `pre-batch-hook` +
  `batch-workers` + `post-batch-hook` durations, plus the task count from
  `batch-workers`'s `meta.tasks`.
- **% of total**: each phase/batch duration ÷ total wall time.
- **Slowest phase(s)**: the top 1-3 by absolute duration.
- **Batch efficiency**: number of batches vs total tasks across all batches —
  many single-task batches suggests an over-serialized dependency graph
  (tasks marked dependent that didn't need to be); one huge batch with a wide
  spread between the fastest and slowest task-worker isn't visible at this
  granularity (worker-level detail isn't logged) — say so as a known gap
  rather than inventing per-task numbers.

Format every duration as `Xm Ys` (or `Xs` under a minute). Never report a
percentage or duration you didn't compute from an actual ts pair.

### Step 2b — Active vs idle (test-gate evidence cross-reference)

Wall time alone lies: phase windows include human absence and stalled
workers. Cross-reference each window against the test-gate evidence journal,
which records every real test-runner execution with a UTC timestamp:

```bash
EF="$(git rev-parse --path-format=absolute --git-common-dir)/claude-test-gate/evidence.jsonl"
```

Each line is `{"type":"test","family":"unit"|"e2e","ts":"2026-09-18T21:56:03Z","cmd":"..."}`
(ignore `type:"commit"` lines). If the file is missing, print one line
`(no evidence.jsonl — active/idle breakdown unavailable)` and skip this step.

For each `batch-workers` window, the `post-implementation` window and the
`test-suite` window, compute:

- **test runs** inside the window (count), split unit / e2e;
- **largest quiet gap** = the longest interval with no test run, including
  window-start→first-run and last-run→window-end;
- flag the window when the quiet gap exceeds 30 minutes.

Measured reference (2026-09-21, pvcpipesupplies): a 5.2h single-task batch
held 7 test runs and one 294-min gap; a "7.3h test suite" held 6 runs with the
last one 349 min before the end marker. In both cases the time was idle
workers or a paused session, not test execution — the report must say so
rather than recommend "speed up the tests".

Add the counts and gap to the per-batch lines and to the test-suite line in
Step 3, e.g. `batch 4   1 task   5h 10m   [7 test runs, quiet gap 294m ⚠]`.

### Step 3 — Print the report

```
============================================================
BUILD TIMING & ANALYTICS — {plan-name}
============================================================

Total wall time: {Xm Ys}

Phase breakdown:
  pre-implementation hook   {dur}   ({pct}%)
  batch execution (total)   {dur}   ({pct}%)   across {N} batch(es), {M} tasks
  post-implementation hook  {dur}   ({pct}%)
  test suite                {dur}   ({pct}%)
  pre-commit hook           {dur}   ({pct}%)
  commit                    {dur}   ({pct}%)
  post-commit hook          {dur}   ({pct}%)

Per-batch:
  batch 1   {N} tasks   {dur}   (pre-batch {dur}, post-batch {dur})
  batch 2   {N} tasks   {dur}   (pre-batch {dur}, post-batch {dur})
  ...

Slowest: {phase/batch name} at {dur} ({pct}% of total)

Improvement notes:
  - {evidence-based note}
  - {evidence-based note}
============================================================
```

Omit the `pre-batch`/`post-batch` parenthetical for a batch when both are 0s
(the common case — those hooks are usually empty) rather than cluttering every
line with zeros.

### Step 4 — Improvement notes (evidence-based only)

Only include a note when the timing data actually supports it — cite the
number. Candidates, in priority order (include whichever apply, skip the
rest — do not pad the list to look thorough):

0. **Idle, not work** (any window with a quiet gap > 30 min from Step 2b):
   "{window} spent {gap} with no test run ({N} runs in {dur}) — that is a
   stalled/idle worker or a paused session, not test cost. Check the
   plan-orchestrate worker-liveness rule fired; do not optimise the suite for
   this." This note takes precedence over 1 and 4 for the same window.
1. **Test suite dominates** (>30% of total AND Step 2b shows the runs
   actually filled the window): "Test suite took {dur} ({pct}% of
   total) — investigate whether it can be scoped to changed files or run with
   more parallelism (see testing.md's parallel test command)."
2. **Review/hook phase dominates** (`post-implementation` or `pre-commit-hook`
   >25% of total): "{phase} took {dur} — check which agents are enrolled at
   this hook (`.claude/agents/*.md` `phase:` frontmatter) and whether all of
   them are still earning their cost."
3. **Batch-count vs task-count skew**: if batch count ≈ task count (mostly
   1-task batches) and task count > 3: "{N} batches for {M} tasks — dependency
   graph may be more serial than necessary; check task `Depends on` fields for
   dependencies that aren't real."
4. **One batch dominates**: if one batch's duration is >2x the median batch
   duration: "Batch {N} ({dur}) took over 2x the median batch time ({dur}) for
   only {tasks} task(s) — that task likely had disproportionate scope; consider
   splitting similar tasks smaller in future plans."
5. **Incomplete/interrupted phases** found in Step 1: "{phase} has no end
   marker — the run was likely interrupted mid-phase; timing for this build is
   partial."
6. If nothing above applies: "No phase or batch stood out as disproportionate
   — time was spent roughly where expected for a {M}-task plan."

## Output format

Just the printed report (Step 3). No `STATUS:` prefix. If the input file is
missing, only the one-line message from Step 1.

## When in doubt

- Never invent a duration, percentage, or task count not derivable from the
  actual `_timing.jsonl` contents.
- Worker-level (per-task) timing isn't captured — only batch-level. Don't
  imply otherwise; name it as a known gap when it would matter (note 4 above
  is the closest approximation available).
- This agent is pure reporting — it must never edit `_timing.jsonl`,
  `_plan.md`, or any task file.
