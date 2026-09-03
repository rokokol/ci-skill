#!/usr/bin/env bash
# The gate for a skill repository: prove SKILL.md is loadable, that every reference
# beside it is reachable, that no link is dead — and prove each of those checks can
# go red, because a check that has never failed is a decoration.
#
# Nothing here reaches the network, so it is safe on pull requests.
# Needs: shellcheck, shfmt — from PATH; CI provides them via nix develop.
#
# EXAMPLE: adapt `name`, `scripts` and `docs`, then delete this line.
set -euo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$HERE"

# EXAMPLE: the skill's own name, as SKILL.md's frontmatter and the plugin manifest spell it
name=EXAMPLE-skill-name

# One source of truth for what gets linted and checked: these two lists, read by
# nothing else. A second copy drifts, and a drifted list lies.
scripts=(tests/check.sh) # EXAMPLE: every shell script the repo ships
docs=(README.md SKILL.md references/EXAMPLE.md)

fail() {
  echo "check: $1" >&2
  exit 1
}

echo "== the scripts parse and lint"
for s in "${scripts[@]}"; do bash -n "$s"; done
shellcheck "${scripts[@]}"
shfmt -d -i 2 -ci "${scripts[@]}"

echo "== SKILL.md carries the frontmatter an agent loads it by"
# A skill with a malformed or renamed frontmatter is not loaded at all, and nothing
# says so: the agent simply never reaches for it.
head -1 SKILL.md | grep -qx -- '---' || fail "SKILL.md does not open with a frontmatter block"
front=$(sed -n '2,/^---$/p' SKILL.md)
for key in name description license; do
  printf '%s\n' "$front" | grep -q "^$key:" || fail "SKILL.md frontmatter has no $key"
done
printf '%s\n' "$front" | grep -qx "name: $name" ||
  fail "the skill's name is not what the plugin manifest and the readme call it"

echo "== SKILL.md still points at every reference it defers to"
# A reference nothing links to is never loaded, so it rots unread while reading as
# maintained. This is the check that catches a moved paragraph.
for ref in references/*; do
  [ -e "$ref" ] || continue
  grep -qF "$(basename "$ref")" SKILL.md ||
    fail "$ref exists but SKILL.md never sends anyone to it"
done

echo "== every relative link and heading anchor in the docs resolves"
./tests/check-links.sh "${docs[@]}"

echo "== the link checker is able to fail"
if ./tests/check-links.sh tests/fixtures/broken-links.md >/dev/null 2>&1; then
  fail "tests/fixtures/broken-links.md passed the link checker — it cannot catch anything"
fi

echo "== the frontmatter check is able to fail"
# In a throwaway copy, because the check reads the repository it stands in
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cp -r . "$work/repo" 2>/dev/null || true
printf 'no frontmatter here\n' >"$work/repo/SKILL.md"
if (cd "$work/repo" && ./tests/check.sh >/dev/null 2>&1); then
  fail "a SKILL.md with no frontmatter passed the gate — it cannot catch anything"
fi

echo "== the orphan-reference check is able to fail"
cp -r . "$work/orphan" 2>/dev/null || true
mkdir -p "$work/orphan/references"
: >"$work/orphan/references/nothing-points-here.md"
if (cd "$work/orphan" && ./tests/check.sh >/dev/null 2>&1); then
  fail "a reference nothing links to passed the gate — it cannot catch anything"
fi

echo
echo "check: everything holds"
