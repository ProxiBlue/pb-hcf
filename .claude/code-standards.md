# Code Standards — pb-hcf plugin repo

- Agents (agents/*.md): YAML frontmatter with name, description, tools; NO phase/order/mode in source (dormant-by-default — wire stamps the triple at --enable). Document intended phase/order in prose body. Description states trigger + one-line purpose.
- Skills (skills/<name>/SKILL.md): frontmatter name + description; body = imperative instructions to the executing agent; no disable-model-invocation unless the skill must never auto-trigger.
- Shell: bash, `set -u` minimum (`set -euo pipefail` where safe), shellcheck-clean, graceful degrade (missing tool → exit 0 with note, never hard-fail the pipeline).
- Templates: *.dist suffix, `<Vendor>`/`<project>` placeholders, one-line WHY comment per non-obvious rule/skip.
- Docs: every new file referenced from README.md; services follow services/<name>/{docker-compose.yml,README.md} pattern; no secrets ever committed (env files live in ~/.pb-hcf/, mode 600).
- Portability: nothing pps-/project-specific in any template or agent; HCF source never modified.
- Style: match existing files (see agents/codegraph-reviewer.md, skills/wire/SKILL.md as canon).
