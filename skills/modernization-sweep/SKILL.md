---
name: modernization-sweep
description: Apply-mode rector modernization sweep for EXISTING custom Magento code under app/code/<Vendor>/<Module>. Trigger on asks like "modernize module", "rector sweep", "upgrade php conventions", or "run the next modernization pass". Processes exactly one module and one ruleset per invocation off the ordered ladder (UP_TO_PHP_83 → code-quality → type-declaration → dead-code), on its own modernize/<module>-<set> branch, gated by dirty-tree and protected-branch refusals, a post-apply idempotency dry-run, and the module's unit tests — then hands off to the standard review chain. Never merges itself. Designed as bounded, stateful, ralph-loop-friendly grind work; tracks progress in .claude/modernization-state.json.
model: sonnet
---

# /pb-hcf:modernization-sweep

Apply-mode rector sweep for existing custom code, one bounded step at a time. Uses the `templates/rector/rector.php.dist` ladder shipped by task 010. This is grind work, not planning work — designed to be safe to invoke repeatedly (by a human or by a ralph-style loop) without ever compounding risk across more than one module × one ruleset per run.

## Bounded blast radius (design principle)

Every invocation touches **exactly one `app/code/<Vendor>/<Module>` directory** and **exactly one ruleset** from the ordered ladder below. This is deliberate: a rector apply-run across many modules or many rulesets at once produces a diff too large to review safely and too large to bisect if something breaks. One module × one ruleset keeps each diff reviewable, each failure attributable, and each branch revertable in isolation. Never widen scope — even if the caller passes more than one module or ruleset, refuse and ask for one.

## Ordered ruleset ladder

Apply rulesets in this fixed order, one per invocation, never skipping ahead for a module that hasn't completed an earlier rung:

1. `LevelSetList::UP_TO_PHP_83`
2. `SetList::CODE_QUALITY`
3. `SetList::TYPE_DECLARATION`
4. `SetList::DEAD_CODE`

This matches `templates/rector/rector.php.dist` (task 010's ruleset ladder source) exactly — do not invent additional sets here.

## Guardrails — refuse before touching anything

Run these checks BEFORE any rector invocation. Any failure is a hard stop — do not proceed, do not auto-fix the guardrail condition yourself.

1. **Dirty-tree refusal.** `git status --porcelain` must be empty. If it reports any output, refuse: "working tree is dirty — commit, stash, or discard local changes before starting a modernization sweep." Never sweep on top of unrelated uncommitted work.
2. **Protected-branch refusal.** `git rev-parse --abbrev-ref HEAD` must NOT be one of the protected branches: `live`, `uat`, `main`, `master`. If it is, refuse: "refusing to start a modernization sweep on protected branch '<branch>' — check out a starting point first, this skill creates its own branch off it."
3. **Dedicated branch.** Once both checks pass, create the dedicated branch for this exact module × ruleset pair: `git checkout -b modernize/<module>-<set>` (e.g. `modernize/Acme_Catalog-up-to-php-83`). Never reuse an existing branch, never combine two module/ruleset pairs on one branch — this is the branch-level expression of the one-module-one-set guardrail above.

## Process

1. **Apply.** Run the ruleset in apply mode, scoped to this module only:
   ```bash
   vendor/bin/rector process app/code/<Vendor>/<Module> --config=rector.php --only=<ruleset>
   ```
   (Or scope `rector.php`'s `withPaths()` / `withSets()` to just this module + ruleset for the run — never apply the full ladder or the full vendor namespace in one invocation.)
2. **Idempotency check — post-apply empty dry-run.** Immediately re-run the SAME ruleset against the SAME module in `--dry-run` mode:
   ```bash
   vendor/bin/rector process app/code/<Vendor>/<Module> --config=rector.php --only=<ruleset> --dry-run
   ```
   This second dry-run MUST report zero remaining changes (empty diff / "no changes"). A non-empty second dry-run means the apply step did not converge — treat this as a hard failure: do not proceed to tests or commit, do not attempt a third pass automatically, surface the residual diff and stop for human triage.
3. **Run the module's unit tests before committing.** Only after the idempotency check is clean, run the module's own unit test suite (per `.claude/testing.md` if the target project has one, else the project's standard `vendor/bin/phpunit` invocation scoped to `app/code/<Vendor>/<Module>/Test/Unit`). Tests MUST pass before any commit is created. A failing test is a hard stop — do not commit, do not silently skip the failing test, do not weaken the rector ruleset to make it pass; surface the failure and stop for human triage.
4. **Commit.** Only once idempotency is clean AND unit tests pass, stage exactly this module's changed files and commit on the `modernize/<module>-<set>` branch with a message naming the module and ruleset (e.g. `modernize(Acme_Catalog): apply UP_TO_PHP_83`).
5. **Hand off — never self-merge.** This skill's job ends at the commit. Hand the branch to the standard review chain (the project's normal PR / review-agent flow, e.g. `gitnexus-reviewer`, `security-quorum`, human review) exactly as any other feature branch would be. This skill MUST NOT merge, push directly to a protected branch, or fast-forward the branch itself under any circumstance — merging is always a separate, human- or reviewer-gated step.
6. **Record progress.** Update `.claude/modernization-state.json` (see below) marking this module × ruleset cell complete, with the branch name and commit sha, before ending the invocation.

## `.claude/modernization-state.json` — module × ruleset completion matrix

Read (or initialize if absent) before picking the next module/ruleset, write after every commit. One row per module discovered under `app/code/<Vendor>/<Module>` (portable discovery — glob, never hardcode a project's module names), one column per ladder ruleset:

```json
{
  "ladder": ["UP_TO_PHP_83", "CODE_QUALITY", "TYPE_DECLARATION", "DEAD_CODE"],
  "modules": {
    "Acme_Catalog": {
      "UP_TO_PHP_83": { "status": "done", "branch": "modernize/Acme_Catalog-up-to-php-83", "commit": "<sha>" },
      "CODE_QUALITY": { "status": "pending" },
      "TYPE_DECLARATION": { "status": "pending" },
      "DEAD_CODE": { "status": "pending" }
    }
  },
  "updatedAt": "<ISO timestamp>"
}
```

Cell statuses: `pending` (not yet attempted), `done` (applied, idempotent, tests green, committed, handed off), `blocked` (idempotency or test failure needs human triage — record the reason). Never mark a cell `done` without a passing idempotency check AND passing unit tests AND a commit sha.

Module discovery for "pick next" is a glob over `app/code/<Vendor>/<Module>/` — never a hardcoded project-specific module list — so this skill stays portable across projects. When no module/ruleset argument is passed, pick the smallest module (by file count) with the earliest incomplete ladder rung, per the flow in this task's context.

## Ralph-loop note — safe completion promise

This skill is designed to be re-invoked by a human or a ralph-style automated loop without a plan or supervision beyond the guardrails above. The **only safe signal that the whole sweep is complete** is: every cell in `.claude/modernization-state.json`'s module × ruleset matrix reads `done` (or an explicitly accepted `blocked` reason recorded by a human). Do not treat "no errors on the last run" or "N consecutive clean invocations" as a completion promise — always re-check the state matrix. A loop driving this skill should stop dispatching new invocations only when the matrix is full, and should surface any `blocked` cells for human triage rather than looping past them.

## What this skill does NOT do

- **Does not merge.** Never merges, fast-forwards, or pushes to a protected branch. Hands off the committed branch to the standard review chain every time — no exceptions, no "trivial diff" shortcut.
- **Does not widen scope.** Never applies more than one ruleset or touches more than one module in a single invocation, even when asked to "do the whole ladder" or "sweep the whole vendor namespace" — refuse and explain the bounded-blast-radius design instead.
- **Does not touch `vendor/` or `generated/`.** Scope is always `app/code/<Vendor>/<Module>`, matching `templates/rector/rector.php.dist`'s own skip list.
- **Does not proceed past a failed guardrail, a non-empty second dry-run, or a failing test suite.** Every one of those is a hard stop for human triage, not something this skill auto-resolves.
- **Does not run on a dirty tree or a protected branch.** See Guardrails above.
