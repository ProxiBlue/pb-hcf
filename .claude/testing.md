# Testing — pb-hcf plugin repo

Plugin repo: markdown agents/skills, shell scripts, JSON/JSON5/YAML templates. No PHP runtime, no phpunit.

## Test commands (run from repo root)
- Shell: `shellcheck scripts/*.sh hooks/*.sh templates/captainhook/bin/*.sh templates/captainhook/bin/git-hooks/*.sh` (add new script paths as created)
- JSON: `python3 -m json.tool <file> >/dev/null` for every *.json; JSON5 dist files: strip //-comments then parse, or verify with `python3 -c "import json5"` if available (fallback: manual comment-strip + json.tool)
- YAML frontmatter: for every agents/*.md and skills/*/SKILL.md — `python3 -c "import yaml,sys; d=sys.stdin.read().split('---')[1]; yaml.safe_load(d)"` 
- PHP templates (rector.php.dist): `php -l` if php available on host, else `docker run --rm -v $PWD:/w php:8.3-cli php -l /w/<file>`
- Secrets grep (must return 0 hits): `grep -rE '(ff15ea68|9c111c47|BUGSINK_API_TOKEN=[a-f0-9])' --include='*' . --exclude-dir=.git`

## Definition of RED/GREEN for doc tasks
Requirements phrased as `it ...` map to greppable/parseable assertions on the produced files (frontmatter fields, required sections, exit codes of scripts run with --help/dry inputs). Write the file, then run the mapped assertion command; GREEN = assertion passes.

## Full suite (pre-commit)
Run all of the above across the repo. All must pass before commit.
