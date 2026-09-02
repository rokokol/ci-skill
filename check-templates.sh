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
shellcheck check-templates.sh ci.sh templates/no-secrets.sh
shfmt -d -i 2 -ci check-templates.sh ci.sh templates/no-secrets.sh
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

echo
echo "check-templates: everything holds"
