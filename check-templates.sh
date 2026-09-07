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
scripts=(check-templates.sh ci.sh templates/no-secrets.sh templates/check-skill.sh templates/check-pins.sh tests/fixtures/planted-secrets.sh)
shellcheck "${scripts[@]}"
shfmt -d -i 2 -ci "${scripts[@]}"

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

echo "== the pin guard passes this repository's workflows and the templates, proven per shape"
# check-pins.sh plants every shape it claims to catch and every pinned spelling on each
# run, so running it is both the guard on these workflows and the proof of the template
templates/check-pins.sh .github/workflows templates/github/workflows

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
# Clean first, with no .gitignore. The gate is now scanning its own source, so every
# pattern that matched its own text would surface right here too
if ! (cd "$sec" && ./tests/no-secrets.sh >/dev/null 2>&1); then
  (cd "$sec" && ./tests/no-secrets.sh) || true
  rm -rf "$sec"
  fail "the secret gate reddens with no .gitignore or a pattern matches its own source"
fi
# An ignored path forced into the index must be named and rejected. check-ignore needs
# --no-index for this: without it, Git deliberately skips tracked paths
mkdir -p "$sec/user"
printf 'user/\n' >"$sec/.gitignore"
printf 'private preference\n' >"$sec/user/preferences.md"
git -C "$sec" add .gitignore
git -C "$sec" add -f user/preferences.md
if out=$(cd "$sec" && ./tests/no-secrets.sh 2>&1); then
  rm -rf "$sec"
  fail "the secret gate accepts a tracked path covered by .gitignore"
fi
if ! printf '%s\n' "$out" | grep -qxF "secret-gate: tracked path is covered by .gitignore: user/preferences.md"; then
  printf '%s\n' "$out" >&2
  rm -rf "$sec"
  fail "the secret gate rejects an ignored tracked path without naming it"
fi
rm -f "$sec/.gitignore" "$sec/user/preferences.md"
git -C "$sec" add -A
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
