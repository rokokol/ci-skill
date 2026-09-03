#!/usr/bin/env bash
# Lints the workflow templates with actionlint, then proves the lint can fail at all by
# feeding it the known-bad fixture. A checker that cannot go red is not a checker.
#
# Needs: actionlint, shellcheck, shfmt — from PATH; CI provides them via nix develop
set -euo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$HERE"

fail() {
  echo "check-templates: $1" >&2
  exit 1
}

echo "== the scripts lint themselves, templates included"
shellcheck check-templates.sh ci.sh templates/no-secrets.sh templates/check-skill.sh tests/fixtures/planted-secrets.sh
shfmt -d -i 2 -ci check-templates.sh ci.sh templates/no-secrets.sh templates/check-skill.sh tests/fixtures/planted-secrets.sh
pyflakes templates/falsify.py

echo "== workflow templates pass actionlint"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/.github/workflows"
cp templates/github/workflows/*.yml "$work/.github/workflows/"
(cd "$work" && actionlint .github/workflows/*.yml)

echo "== the lint can fail: the known-bad fixture must go red"
bad=$(mktemp -d)
mkdir -p "$bad/.github/workflows"
cp tests/fixtures/must-fail.yml "$bad/.github/workflows/"
if (cd "$bad" && actionlint .github/workflows/*.yml >/dev/null 2>&1); then
  rm -rf "$bad"
  fail "actionlint passed tests/fixtures/must-fail.yml — it cannot catch anything"
fi
rm -rf "$bad"

echo "== the pin guard is able to fail, and does not fail on itself"
# One source of truth: the pattern is read out of the template that carries it, never
# spelled a second time here — two copies of a regex disagree within a month
pattern=$(sed -n "s/.*grep -rEn '\(.*\)' \.github\/workflows.*/\1/p" templates/github/workflows/build.yml)
[ -n "$pattern" ] || fail "could not read the pin guard's pattern out of the build.yml template"
grep -qE "$pattern" tests/fixtures/unpinned-workflow.yml ||
  fail "the pin guard's pattern matches nothing in tests/fixtures/unpinned-workflow.yml — it cannot catch anything"
# The guard greps the workflows including the file that carries it, so a literal
# sub-pattern would redden the repo on itself — see references/pinning.md
if grep -qE "$pattern" templates/github/workflows/build.yml; then
  fail "the pin guard's pattern matches the template carrying it — break the self-match, see references/pinning.md"
fi

echo "== the secret gate catches every shape it claims, and is quiet on itself"
# The template is exercised end to end, in a throwaway repository, rather than by
# re-testing its regexes here: the gate's subject is "what git tracks", and only a
# real repository can answer that
sec=$(mktemp -d)
git -C "$sec" init -q
git -C "$sec" config user.email ci@example.invalid
git -C "$sec" config user.name ci
mkdir -p "$sec/tests"
cp templates/no-secrets.sh "$sec/tests/"
git -C "$sec" add -A
# Clean first. The gate is now scanning its own source, so every pattern that
# matched its own text would surface right here
if ! (cd "$sec" && ./tests/no-secrets.sh >/dev/null 2>&1); then
  (cd "$sec" && ./tests/no-secrets.sh) || true
  rm -rf "$sec"
  fail "the secret gate reddens on its own source — a pattern is matching its own text"
fi
# Then one planted value per shape, each on its own tracked file, so a single
# over-broad pattern cannot cover for a dead one
i=0
while IFS= read -r line; do
  i=$((i + 1))
  printf '%s\n' "$line" >"$sec/planted-$i.txt"
  git -C "$sec" add -A
  if (cd "$sec" && ./tests/no-secrets.sh >/dev/null 2>&1); then
    printf 'the gate stayed green on: %s\n' "${line:0:24}…" >&2
    rm -rf "$sec"
    fail "a planted secret shape went unnoticed — see tests/fixtures/planted-secrets.sh"
  fi
  rm -f "$sec/planted-$i.txt"
  git -C "$sec" add -A
done < <(./tests/fixtures/planted-secrets.sh)
[ "$i" -gt 0 ] || fail "planted-secrets.sh produced nothing to plant"
echo "   $i shapes planted, $i caught"
rm -rf "$sec"

echo
echo "check-templates: everything holds"
