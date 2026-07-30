# CaptainHook template — deterministic git-level gates for any Magento project

Install into a project:

```bash
cp captainhook.json.dist <project>/captainhook.json
cp -r bin/ <project>/bin/          # guard scripts (uat-merge/branch-guard, ensure-live-merged, pre-push-check)
composer require --dev captainhook/captainhook
vendor/bin/captainhook install -f
```

Gates: pre-commit uat-merge-guard; pre-push = unit phpunit (--stop-on-failure) + branch-aware full-check; post-checkout/post-merge guards + conditional rebuild (composer.json/lock changes only).

Adjust phpunit config path per project testing.md. Wired in pps 2026-07-30; lcdscreen-mageos pending (project not running).
