# Rector template — deterministic PHP-8.3 modernization for Magento 2 custom code

Scope: `*.php` under `app/code/<Vendor>`, excluding `generated/`, `vendor/`, and test fixtures — same
changed-files convention used by the rest of the verification spine (rector enforcement wiring,
modernization-sweep skill).

## Install

```bash
composer require --dev rector/rector
cp templates/rector/rector.php.dist <project>/rector.php
```

Replace the `<Vendor>` placeholder in `rector.php` with your module vendor namespace, e.g.
`app/code/Acme`. Add one `withPaths()` entry per vendor namespace if a project ships more than one.

## Dry-run usage

```bash
vendor/bin/rector process app/code/<Vendor> --dry-run --config=rector.php
```

Drop `--dry-run` to apply. Always run the dry-run diff through code review before applying — rector
sets included here (`LevelSetList::UP_TO_PHP_83`, `SetList::CODE_QUALITY`, `SetList::TYPE_DECLARATION`,
`SetList::DEAD_CODE`) are broad, and the `withSkip()` block only excludes the rules known to actively
fight Magento's DI/plugin mechanics (see `rector.php.dist` comments for the one-line WHY per skip) —
it does not guarantee every remaining rule is a safe no-review auto-apply for a given codebase.

## phpstan baseline-ratchet companion pattern

Rector and phpstan are complementary, not the same tool: rector rewrites code, phpstan only reports.
Pair them so static-analysis debt can only shrink, never grow:

1. **Generate a baseline** against the current codebase so existing violations don't block CI:
   ```bash
   composer require --dev phpstan/phpstan
   vendor/bin/phpstan analyse app/code/<Vendor> --level=0 --generate-baseline
   ```
2. **Raise the level** in small steps (`--level=1`, `2`, `3`, ...) as rector's `TYPE_DECLARATION` and
   `DEAD_CODE` sets add the missing type coverage that unblocks each level. Re-generate the baseline
   after every level bump so newly-surfaced findings at the new level are captured, not silently
   allowed everywhere.
3. **Ratchet, never grow**: the baseline file must shrink or stay flat over time, never grow. Enforce
   this in CI with a two-step check — run `phpstan analyse` with `--generate-baseline` to a scratch
   file, then fail the build if the scratch baseline has more ignored-error entries than the committed
   one (e.g. `git diff --stat -- phpstan-baseline.neon` gated on a line-count-not-increasing rule, or
   a small script that counts `identifier:`/`message:` entries in both files and compares). Committing
   a bigger baseline than before should require an explicit human override, not pass silently.
4. Treat `phpstan-baseline.neon` entries as a to-do list rector's next sweep should shrink, not a
   permanent allowlist.

## Magento-2-rector-extension maturity verdict (checked 2026-07-31)

**No maintained Magento-2-specific rector rule set exists.** Evidence:

- Packagist search for `magento rector` / `rector magento` / `magento2-rector` / `rector-magento2`
  returns no package that ships Magento-2-aware rector rules (checked via `packagist.org/search.json`,
  2026-07-31).
- GitHub code/repo search for `magento rector`, `magento-rector`, `rector-magento` returns zero
  repositories (`api.github.com/search/repositories`, 2026-07-31).
- The closest hit, `yireo/rector-php-extensions`, is a small generic rule/file-processor package (not
  Magento-specific — its own README describes it as "RectorPHP rules and file processors") last pushed
  2022-07-04 (per the GitHub API `pushed_at` field) with two of its three rules marked "Not working" in
  its own README. Treat it as abandoned, not as a viable dependency.
- Rector's own upstream README (`rectorphp/rector`, `main` branch, fetched 2026-07-31) maintains an
  "Empowered by Community" list of framework-specific companion packages (Drupal, Craft CMS, Shopware,
  TYPO3, Sulu, Laravel, Contao, CakePHP, etc.) — Magento is not on that list.

**Consequence**: this template intentionally uses only generic PHP-level rector sets
(`LevelSetList::UP_TO_PHP_83`, `SetList::CODE_QUALITY`, `SetList::TYPE_DECLARATION`,
`SetList::DEAD_CODE`) plus an explicit hand-written Magento skip list (see `rector.php.dist`), rather
than delegating Magento-awareness to a framework-specific rector package. Re-check this verdict before
every major Magento or rector upgrade — record the new check date here if the landscape changes.

## Rule/version provenance

- `rector/rector` latest at check time: `2.5.9` (installed via `composer require rector/rector --dev`
  in a scratch container, 2026-07-31).
- Set-list class names (`LevelSetList::UP_TO_PHP_83`, `SetList::CODE_QUALITY`,
  `SetList::TYPE_DECLARATION`, `SetList::DEAD_CODE`) verified against
  `rectorphp/rector-src` `src/Set/ValueObject/{LevelSetList,SetList}.php` and the installed
  `vendor/rector/rector/templates/rector.php.dist` init template, 2026-07-31.
- Magento plugin/interceptor limitations (`__construct` not pluggable, final classes/methods not
  pluggable, plugin methods must match the observed method's parameter list) verified against
  `developer.adobe.com/commerce/php/development/components/plugins`, 2026-07-31.
- PHP readonly-class inheritance restriction verified against the PHP readonly-classes RFC
  (`wiki.php.net/rfc/readonly_classes`), which is normative PHP language behaviour and not
  expected to change per-version.
