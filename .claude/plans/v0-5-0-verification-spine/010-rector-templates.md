# Task 010: Rector templates

**Status**: pending
**Depends on**: none
**Retry count**: 0

## Description
Ship templates/rector/: rector.php.dist (PHP 8.3 level + code-quality + type-declaration + dead-code sets, custom-namespace paths placeholder, Magento skip rules) + README.md (install, dry-run usage, phpstan baseline-ratchet companion pattern). Verify current Magento-specific rector-set maturity and encode findings.

## Context
- rector.php.dist: paths [app/code/<Vendor>], skip: generated/, Test fixtures needing raw patterns, Magento interceptor/ObjectManager-related rules known to fight the framework (research at implementation: e.g. readonly-class vs interceptor generation, constructor promotion vs di.xml reflection — verify against rector + magento current docs, encode as explicit skip list with one-line WHY per skip)
- README: composer require --dev rector/rector; dry-run command shape vendor/bin/rector process <paths> --dry-run --config=rector.php; phpstan ratchet section: generate baseline, raise level, baseline shrinks over time, never grows (CI check idea documented)
- Research requirement: check whether a maintained Magento 2 rector extension exists NOW; if yes document as optional add-on, if no state so with date

## Requirements (Test Descriptions)
- [ ] `it ships rector.php.dist that php -l parses cleanly`
- [ ] `it scopes paths to a vendor placeholder and never includes vendor or generated dirs`
- [ ] `it carries an explicit Magento skip list with a one-line reason per skipped rule`
- [ ] `it documents the phpstan baseline ratchet pattern in the README`
- [ ] `it records the Magento-rector-extension maturity verdict with check date`

## Acceptance Criteria
- Config usable verbatim in a Magento project after one placeholder substitution
