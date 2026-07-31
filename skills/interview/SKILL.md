---
name: interview
description: Pre-plan scope builder that interviews the user one question at a time to flesh out scope before a build starts. Trigger naturally on vague build asks such as "flesh out scope", "help me spec", "not sure what I want", "spec this out", or "what should I build" — no explicit invocation required. Scores the emerging spec on a 4-dimension clarity scorecard and refuses handoff to plan-create below threshold.
model: sonnet
---

# /pb-hcf:interview

Pre-plan scope builder. Turns a vague build ask into a clarity-scored spec that `/hcf:plan-create` consumes verbatim. Implements the Harper Reed one-question-at-a-time interview pattern.

**Auto-trigger, no gating.** This skill carries no `disable-model-invocation` flag — it must fire naturally whenever the user's ask is vague about scope (see trigger phrases in the frontmatter description above). Do not require an explicit `/pb-hcf:interview` invocation; treat any vague build ask as the trigger.

## Flow

1. **Intake ask** — read the user's raw request as the interview seed.
2. **Silent codebase recon** — glob/read any artefacts the user named (files, modules, configs) before asking anything. Never ask the user for information recon can obtain itself.
3. **Question loop** — apply the one-question-per-turn rule: ask exactly ONE question per turn, never bundle two questions into a single turn. Prefer the `AskUserQuestion` tool when available; fall back to plain prose when it is not.
   - Each turn, pick the lowest-scoring dimension on the current scorecard and craft the single question that would most improve it.
   - Never ask more than 10 questions total in one interview. Each of the (at most) 10 questions targets only the current lowest-scoring dimension.
4. **Scorecard** — after every answer, update and show the running scorecard (see below) before asking the next question.
5. **Threshold reached** — once the total is 16/20 or above, stop asking questions and emit the Interview Spec block.
6. **Threshold not reached** — if still under 16/20 after 10 questions, apply the refusal rule below.

## Scorecard: 4-dimension scorecard (Goal/Constraints/Success Criteria/Context, 0-5 each)

Maintain a visible 4-dimension scorecard, updated every turn, across exactly these four dimensions:

| Dimension | Score |
|---|---|
| Goal | 0-5 |
| Constraints | 0-5 |
| Success Criteria | 0-5 |
| Context | 0-5 |

Show it after every turn, e.g.:

```
Scorecard: Goal 4/5 · Constraints 2/5 · Success Criteria 3/5 · Context 3/5 — total 12/20
```

## Refusal rule: 16/20 threshold

Below the 16/20 threshold, refuse to hand off to `/hcf:plan-create`. Tell the user the current total out of 20 and which dimensions are weak, and offer two options: answer more questions, or force proceed.

If the user forces proceed while still below 16/20, emit the Interview Spec block anyway, stamped with:

```
CLARITY DEBT: <dimensions scored below 4/5>
```

List every dimension currently scoring below 4/5 in the `CLARITY DEBT` stamp.

## Output: `## Interview Spec` block

At handoff — whether reached at threshold or forced with a `CLARITY DEBT` stamp — emit exactly one markdown block headed `## Interview Spec`, formatted for plan-create args consumption:

```
## Interview Spec

**Goal:** ...
**Constraints:** ...
**Success Criteria:** ...
**Context:** ...
**Open-but-defaulted items:** ...
```

(If forced below threshold, the `CLARITY DEBT: <dimensions below 4/5>` stamp is prepended immediately above this block.)

## plan-create handoff

After emitting the `## Interview Spec` block, suggest running `/hcf:plan-create` with the block pasted as its args. This is the plan-create handoff: plan-create consumes the `## Interview Spec` block verbatim as its scope input — do not paraphrase or reformat it before suggesting the handoff.

## What this skill does NOT do

- Does not gate behind `disable-model-invocation` — it stays eligible for model-invoked auto-trigger on vague build asks.
- Does not write files, run code, or call `/hcf:plan-create` itself — output ends at the `## Interview Spec` block plus the handoff suggestion.
- Does not exceed 10 questions per interview, regardless of clarity score.
