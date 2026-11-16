#!/usr/bin/env bash
# Tests for composer-drift-check.sh. Run: scripts/composer-drift-check.test.sh
# Builds throwaway git repos under a temp dir; a stub `composer` on PATH stands
# in for the dry-run so no network or real vendor tree is needed.

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUT="$HERE/composer-drift-check.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/composer-drift-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0

lock() { # lock <name=version>... -> composer.lock JSON on stdout
  local first=1 pair
  printf '{"packages":['
  for pair in "$@"; do
    [[ $first -eq 1 ]] || printf ','
    first=0
    printf '{"name":"%s","version":"%s"}' "${pair%%=*}" "${pair#*=}"
  done
  printf '],"packages-dev":[]}\n'
}

new_repo() { # new_repo <name> -> path; committed composer.json + composer.lock (a/one 1.0.0, b/two 2.0.0)
  local d="$WORK/$1"
  mkdir -p "$d"
  (
    cd "$d" || exit 1
    git init -q .
    git config user.email test@example.com
    git config user.name test
    echo '{"require":{"a/one":"1.0.0","b/two":"^2.0"}}' > composer.json
    lock a/one=1.0.0 b/two=2.0.0 > composer.lock
    git add -A
    git commit -q -m base
  )
  echo "$d"
}

stub_composer() { # stub_composer <dir> <exit-code> <output...> -> bin dir with a fake composer
  local bin="$1/bin" rc="$2"
  shift 2
  mkdir -p "$bin"
  {
    echo '#!/usr/bin/env bash'
    echo "cat <<'OUT'"
    printf '%s\n' "$@"
    echo 'OUT'
    echo "exit $rc"
  } > "$bin/composer"
  chmod +x "$bin/composer"
  echo "$bin"
}

run() { # run <dir> [env assignments / args...] ; sets OUT + RC
  local d="$1"
  shift
  OUT="$(cd "$d" && env "$@" bash "$SUT" 2>&1)"
  RC=$?
}

check() { # check <label> <expected-rc> [grep-pattern]
  local label="$1" want="$2" pat="${3:-}"
  if [[ "$RC" -ne "$want" ]]; then
    FAIL=$((FAIL + 1)); echo "FAIL: $label — exit $RC, wanted $want"; echo "$OUT" | sed 's/^/    /'; return
  fi
  if [[ -n "$pat" ]] && ! grep -Eq -- "$pat" <<< "$OUT"; then
    FAIL=$((FAIL + 1)); echo "FAIL: $label — output lacks /$pat/"; echo "$OUT" | sed 's/^/    /'; return
  fi
  PASS=$((PASS + 1)); echo "ok:   $label"
}

NOVENDOR=COMPOSER_DRIFT_NO_VENDOR=1

# 1. no composer.json -> nothing to check
d="$WORK/nocomposer"; mkdir -p "$d"; (cd "$d" && git init -q . && git config user.email t@example.com && git config user.name t && echo x > f && git add -A && git commit -q -m base)
run "$d" "$NOVENDOR"; check "no composer.json exits 0" 0 'nothing to check'

# 2. unchanged lock -> clean
d="$(new_repo unchanged)"
run "$d" "$NOVENDOR"; check "unchanged lock is clean" 0 'composer-drift: clean'

# 3. package removed -> drift, named
d="$(new_repo removed)"; lock a/one=1.0.0 > "$d/composer.lock"
run "$d" "$NOVENDOR"; check "removed package is drift" 1 'REMOVED +b/two 2\.0\.0'

# 4. version changed -> drift, old -> new
d="$(new_repo changed)"; lock a/one=1.0.1 b/two=2.0.0 > "$d/composer.lock"
run "$d" "$NOVENDOR"; check "changed version is drift" 1 'CHANGED +a/one 1\.0\.0 -> 1\.0\.1'

# 5. package added -> drift
d="$(new_repo added)"; lock a/one=1.0.0 b/two=2.0.0 c/three=3.0.0 > "$d/composer.lock"
run "$d" "$NOVENDOR"; check "added package is drift" 1 'ADDED +c/three 3\.0\.0'

# 6. a STAGED lock change is still seen (working tree vs ref, index ignored)
d="$(new_repo staged)"; lock a/one=1.0.0 > "$d/composer.lock"; (cd "$d" && git add composer.lock)
run "$d" "$NOVENDOR"; check "staged removal is drift" 1 'REMOVED +b/two'

# 7. dev packages count
d="$(new_repo devpkg)"; printf '{"packages":[{"name":"a/one","version":"1.0.0"},{"name":"b/two","version":"2.0.0"}],"packages-dev":[{"name":"d/dev","version":"0.1.0"}]}\n' > "$d/composer.lock"
run "$d" "$NOVENDOR"; check "added dev package is drift" 1 'ADDED +d/dev 0\.1\.0'

# 8. explicit ref argument: drift committed on the branch is seen against the base
d="$(new_repo refarg)"; base="$(cd "$d" && git rev-parse HEAD)"; lock a/one=1.0.0 > "$d/composer.lock"; (cd "$d" && git commit -q -am "drop b/two")
run "$d" "$NOVENDOR"; check "committed change is clean against HEAD" 0 'composer-drift: clean'
OUT="$(cd "$d" && COMPOSER_DRIFT_NO_VENDOR=1 bash "$SUT" "$base" 2>&1)"; RC=$?
check "committed change is drift against the base ref" 1 'REMOVED +b/two'
run "$d" "$NOVENDOR" "COMPOSER_DRIFT_BASE=$base"; check "COMPOSER_DRIFT_BASE works like the argument" 1 'REMOVED +b/two'

# 9. bad ref -> cannot check
d="$(new_repo badref)"
OUT="$(cd "$d" && COMPOSER_DRIFT_NO_VENDOR=1 bash "$SUT" no-such-ref 2>&1)"; RC=$?
check "bad ref exits 2" 2 'CANNOT CHECK'

# 10. malformed lock -> cannot check, never a pass
d="$(new_repo badlock)"; echo '{not json' > "$d/composer.lock"
run "$d" "$NOVENDOR"; check "malformed lock exits 2" 2 'CANNOT CHECK'

# 11. outside a git repo -> cannot check
d="$WORK/nogit"; mkdir -p "$d"; echo '{}' > "$d/composer.json"
OUT="$(cd "$d" && GIT_CEILING_DIRECTORIES="$WORK" bash "$SUT" 2>&1)"; RC=$?
check "not a git repo exits 2" 2 'CANNOT CHECK'

# 12. vendor matches lock (stub composer: nothing to do) -> clean
d="$(new_repo vendorclean)"; mkdir -p "$d/vendor"
bin="$(stub_composer "$d" 0 'Installing dependencies from lock file (including require-dev)' 'Nothing to install, update or remove')"
run "$d" "PATH=$bin:$PATH"; check "vendor matching lock is clean" 0 'vendor/ matches composer.lock'

# 13. vendor differs from lock (stub composer: pending removal) -> drift, operation shown
d="$(new_repo vendordrift)"; mkdir -p "$d/vendor"
bin="$(stub_composer "$d" 0 'Package operations: 0 installs, 0 updates, 1 removal' '  - Removing hyva-themes/magento2-luma-checkout (1.1.6)')"
run "$d" "PATH=$bin:$PATH"; check "pending vendor removal is drift" 1 'Removing hyva-themes/magento2-luma-checkout'

# 14. stale lock warning from composer -> drift
d="$(new_repo stalelock)"; mkdir -p "$d/vendor"
bin="$(stub_composer "$d" 0 'Warning: The lock file is not up to date with the latest changes in composer.json.' 'Nothing to install, update or remove')"
run "$d" "PATH=$bin:$PATH"; check "stale lock warning is drift" 1 'out of date with composer.json'

# 15. composer dry-run itself fails -> cannot check
d="$(new_repo composerfail)"; mkdir -p "$d/vendor"
bin="$(stub_composer "$d" 1 'Your requirements could not be resolved')"
run "$d" "PATH=$bin:$PATH"; check "failing composer dry-run exits 2" 2 'CANNOT CHECK'

# 16. no vendor/ -> vendor check skipped, lock result stands
d="$(new_repo novendor)"
bin="$(stub_composer "$d" 1 'should never be called')"
run "$d" "PATH=$bin:$PATH"; check "no vendor dir skips vendor check" 0 'vendor check skipped'

# 17. the script leaves the working tree and index untouched
d="$(new_repo readonly)"; lock a/one=1.0.0 > "$d/composer.lock"; echo wip > "$d/wip.txt"
before="$(cd "$d" && git status --porcelain && git stash list | wc -l)"
run "$d" "$NOVENDOR"
after="$(cd "$d" && git status --porcelain && git stash list | wc -l)"
if [[ "$before" == "$after" ]]; then PASS=$((PASS + 1)); echo "ok:   working tree and index untouched"; else FAIL=$((FAIL + 1)); echo "FAIL: working tree changed by the check"; fi

echo
echo "composer-drift-check tests: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
