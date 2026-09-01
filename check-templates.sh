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

echo "== this script lints itself"
shellcheck check-templates.sh
shfmt -d -i 2 -ci check-templates.sh

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

echo "== VERSION matches CHANGELOG (the standard, applied to itself)"
ver=$(cat VERSION)
grep -qF "## [$ver]" CHANGELOG.md ||
  fail "VERSION says $ver but CHANGELOG.md has no ## [$ver] heading"

echo
echo "check-templates: everything holds"
