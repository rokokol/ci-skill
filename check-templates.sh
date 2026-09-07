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

echo "== this repository passes the skill gate it hands out"
# check-skill.sh proves its own checks able to fail on every run, so running it here is
# both the gate on this skill's docs and the falsification of the template
templates/check-skill.sh -n ci .

echo "== the pin guard is able to fail, and does not fail on itself"
# One source of truth: the pattern is read out of the template that carries it, never
# spelled a second time here — two copies of a regex disagree within a month
pattern=$(sed -n "s/.*grep -rEn '\(.*\)' \.github\/workflows.*/\1/p" templates/github/workflows/build.yml)
[ -n "$pattern" ] || fail "could not read the pin guard's pattern out of the build.yml template"
# Every step of the fixture is one unpinned shape; each must match on its own, or an
# alternative of the pattern can be dead while the others keep the fixture red
n=0
while IFS= read -r step; do
  n=$((n + 1))
  printf '%s\n' "$step" | grep -qE "$pattern" ||
    fail "the pin guard's pattern misses this line of tests/fixtures/unpinned-workflow.yml: $step"
done < <(grep -E '^\s*- run:' tests/fixtures/unpinned-workflow.yml)
[ "$n" -gt 0 ] || fail "tests/fixtures/unpinned-workflow.yml has no run steps — it cannot prove anything"
echo "   $n unpinned shapes, each caught"
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
# Then one planted value per shape, each on its own tracked file, and the gate must
# name that shape: a value caught only by some other, over-broad pattern means the
# pattern meant for it is dead
i=0
while IFS=$'\t' read -r shape value; do
  i=$((i + 1))
  printf '%s\n' "$value" >"$sec/planted-$i.txt"
  git -C "$sec" add -A
  if out=$(cd "$sec" && ./tests/no-secrets.sh 2>&1); then
    printf 'the gate stayed green on: %s\n' "${value:0:24}…" >&2
    rm -rf "$sec"
    fail "a planted secret shape went unnoticed — see tests/fixtures/planted-secrets.sh"
  fi
  if ! printf '%s\n' "$out" | grep -qxF "secret-gate: $shape"; then
    printf '%s\n' "$out" >&2
    rm -rf "$sec"
    fail "the gate went red on ${value:0:24}… but did not call it '$shape' — the pattern for that shape is dead"
  fi
  rm -f "$sec/planted-$i.txt"
  git -C "$sec" add -A
done < <(./tests/fixtures/planted-secrets.sh)
[ "$i" -gt 0 ] || fail "planted-secrets.sh produced nothing to plant"
echo "   $i shapes planted, $i caught"
rm -rf "$sec"

echo
echo "check-templates: everything holds"
