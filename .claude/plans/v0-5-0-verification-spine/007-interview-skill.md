# Task 007: interview skill (clarity-scored scope builder)

**Status**: pending
**Depends on**: none
**Retry count**: 0

## Description
New skill skills/interview/SKILL.md: pre-plan scope builder. One question at a time (Harper Reed pattern), scores the emerging spec across Goal / Constraints / Success Criteria / Context (0-5 each), refuses to hand off to plan-create below threshold 16/20, outputs a spec block plan-create consumes verbatim.

## Context
- Patterns: skills/wire/SKILL.md frontmatter + structure; AskUserQuestion tool for question delivery where available, plain prose fallback
- Flow: intake ask → silent codebase recon (glob/read of named artefacts) → question loop (ONE question per turn, each targeting the lowest-scoring dimension, max 10) → running scorecard shown each turn → at threshold: emit "## Interview Spec" markdown (Goal, Constraints, Success Criteria, Context, Open-but-defaulted items) → suggest /hcf:plan-create with the spec pasted as args
- Refusal rule: below threshold + user forces proceed → emit spec anyway, stamped "CLARITY DEBT: <dimensions below 4>"

## Requirements (Test Descriptions)
- [ ] `it asks exactly one question per turn targeting the lowest-scoring dimension`
- [ ] `it maintains a visible 4-dimension scorecard updated every turn`
- [ ] `it refuses handoff below 16 of 20 unless user overrides`
- [ ] `it stamps CLARITY DEBT dimensions on forced proceed`
- [ ] `it emits an Interview Spec block formatted for plan-create args consumption`

## Acceptance Criteria
- Skill triggers naturally on vague build asks (frontmatter description covers "flesh out scope", "not sure what I want", "help me spec")
