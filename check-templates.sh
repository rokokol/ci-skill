#!/usr/bin/env bash
# This repository's gate: lints every script and workflow template, then proves each thing
# it checks able to fail — actionlint on a known-bad workflow, ci.sh against recorded runs,
# the docs against ci.sh's own dispatch, the travelling checkers, vendor-sync.sh end to end
# and the secret gate. A checker that cannot go red is not a checker.
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
scripts=(check-templates.sh ci.sh vendor-sync.sh check-sh.sh templates/no-secrets.sh templates/check-skill.sh templates/check-pins.sh templates/vendor-sync.sh tests/fixtures/planted-secrets.sh)
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

echo "== ci.sh reads a run that was cancelled, and the log of a job that was not"
# ci.sh was lint-only until now: the tool this skill hands out for reading CI had nothing
# checking what it reads, and both of the bugs below were found by using it. GitHub reports
# a job killed by `timeout-minutes` as `cancelled`, never `failure`, and `failed` selected
# on `failure` alone — so the one run that mattered printed nothing at all. And there was
# no way to read the log of a job that passed, which is exactly what you want the first
# time a job runs and its green needs looking at rather than trusting.
#
# Answered by a stub `gh` reading real captures rather than by talking to GitHub: the
# subject here is ci.sh's own logic, and the stub errors on any call ci.sh does not make,
# so a check cannot pass because the fake quietly returned nothing.
mkdir -p "$work/bin"
ln -sf "$HERE/tests/fixtures/gh-stub" "$work/bin/gh"
stub() { (PATH="$work/bin:$PATH" GH_STUB_DIR="$HERE/tests/fixtures/gh" ./ci.sh "$@" 2>&1); }
out=$(stub failed 34161681702) ||
  fail "ci.sh failed exited nonzero on a cancelled run:"$'\n'"$out"
grep -q 'check.sh (the gate' <<<"$out" ||
  fail "ci.sh failed did not name the step a cancelled job died on — a job killed by timeout-minutes is cancelled, not failure:"$'\n'"$out"
out=$(stub log 34245254549 bash32) ||
  fail "ci.sh log exited nonzero on a job that succeeded:"$'\n'"$out"
grep -q 'GNU bash, version 3.2.57' <<<"$out" ||
  fail "ci.sh log did not print the log of a job that succeeded:"$'\n'"$out"
# And a run where nothing went wrong has to say so: silence there is indistinguishable
# from the bug above, which is how the bug survived being used
out=$(stub failed 34245254549) ||
  fail "ci.sh failed exited nonzero on a run where everything passed:"$'\n'"$out"
grep -q 'nothing went wrong' <<<"$out" ||
  fail "ci.sh failed printed nothing for a run where nothing went wrong, which reads exactly like a reader that cannot see:"$'\n'"$out"

echo "== ci.sh's help, and every doc that lists the harness, agree with its dispatch"
# ci.sh's own dispatch is the list. README restates it for readers, and a restated list
# drifts: `log` shipped and stayed missing from every doc until a review caught it. The
# check is the bash-best-practices skill's check-sh.sh, vendored: it reads the
# subcommands, flags and exit codes out of ci.sh, holds the help to them, and holds the
# docs' `ci.sh …` mentions to the dispatcher — README and SKILL.md in both directions,
# ops.md backwards only, since it sends the reader to the help instead of restating it —
# and plants its own defects on every run, so nothing here has to prove it can fail. On
# its first run it found the help printing a fixed line range, `--repo` unmentioned and
# exit 1 unlisted
./check-sh.sh -n ci.sh -d README.md -m references/ops.md -d SKILL.md ci.sh

echo "== this repository passes the skill gate it hands out"
# check-skill.sh proves its own checks able to fail on every run, so running it here is
# both the gate on this skill's docs and the falsification of the template
templates/check-skill.sh -n ci .

echo "== the pin guard passes this repository's workflows and the templates, proven per shape"
# check-pins.sh plants every shape it claims to catch and every pinned spelling on each
# run, so running it is both the guard on these workflows and the proof of the template
templates/check-pins.sh .github/workflows templates/github/workflows

echo "== the travelling checkers keep the promises their headers make"
# Every header promises exit 2 for a usage error, and --help is the header itself. Both
# were broken once: `${2:?}` made bash exit 1 with its own message, and --help printed a
# fixed line range the header had long outgrown, dropping the exit codes and the allow
# marker. check-sh.sh holds each header to its flags, its exit codes and its bash 3.2
# claim, and reads the header's last line by a different means than the scripts use, so a
# help that stops early cannot agree with it by construction; the usage-error probe stays
# here, since it is behaviour rather than shape
out=$(templates/check-skill.sh -n 2>&1) && status=0 || status=$?
[ "$status" -eq 2 ] ||
  fail "check-skill.sh -n with no name exited $status, where its header promises 2 for a usage error:"$'\n'"$out"
grep -q '^check-skill: -n needs a name' <<<"$out" ||
  fail "check-skill.sh -n with no name did not say what is missing:"$'\n'"$out"
for checker in templates/check-skill.sh templates/check-pins.sh templates/vendor-sync.sh; do
  ./check-sh.sh "$checker"
done
# And the vendored copies are the blobs the lock records, this repository's own template
# among them: the cascade that keeps every other repository's copy current starts here
./vendor-sync.sh check

echo "== vendor-sync.sh keeps copies byte-equal to their source, and refuses an edit in place"
# End to end against a source repository reached over file://, the same git plumbing a real
# run uses over https, so nothing here needs the network. Every case below was watched
# failing before the script existed
vs="$work/vs"
up="$vs/owner/src"
mkdir -p "$up/data"
git -C "$up" init -q
git -C "$up" config user.email ci@example.invalid
git -C "$up" config user.name ci
printf '#!/bin/sh\necho one\n' >"$up/tool.sh"
chmod +x "$up/tool.sh"
printf 'a\n' >"$up/data/a.txt"
printf 'b\n' >"$up/data/b.txt"
printf 'on: push\n' >"$up/flow.yml"
git -C "$up" add -A
git -C "$up" commit -qm one
down="$work/down"
mkdir -p "$down"
git -C "$down" init -q
git -C "$down" config user.email ci@example.invalid
git -C "$down" config user.name ci
cp templates/vendor-sync.sh "$down/"
base="file://$vs"
vsync() { (cd "$down" && ./vendor-sync.sh "$@"); }
lock="$down/.github/vendor.lock"

vsync add -u "$base" tool.sh owner/src tool.sh >/dev/null ||
  fail "vendor-sync add could not take a file from its source"
vsync add -u "$base" data/ owner/src data/ >/dev/null ||
  fail "vendor-sync add could not take a directory from its source"
cmp -s "$up/tool.sh" "$down/tool.sh" || fail "add left tool.sh different from its source"
[ -x "$down/tool.sh" ] || fail "add dropped the executable bit tool.sh has in its source"
cmp -s "$up/data/b.txt" "$down/data/b.txt" || fail "add left data/b.txt different from its source"
vsync check >/dev/null || fail "check rejected the copies add had just made"
git -C "$down" add -A
git -C "$down" commit -qm vendored

# A change in the source arrives, and the lock records the commit it came from
printf '#!/bin/sh\necho two\n' >"$up/tool.sh"
git -C "$up" commit -qam two
vsync update -u "$base" >/dev/null || fail "update failed on a source that had moved"
cmp -s "$up/tool.sh" "$down/tool.sh" || fail "update did not bring tool.sh's new content"
grep -q "^tool.sh owner/src tool.sh $(git -C "$up" rev-parse HEAD) " "$lock" ||
  fail "the lock does not record the commit tool.sh now comes from:"$'\n'"$(cat "$lock")"
[ -x "$down/tool.sh" ] || fail "update dropped the executable bit"

# Nothing moved, so nothing changes — not even the lock
cp "$lock" "$work/lock.before"
vsync update -u "$base" >/dev/null || fail "update failed with nothing to do"
cmp -s "$work/lock.before" "$lock" || fail "update rewrote the lock when no source had moved"
# Nor when the source moved without touching what is vendored: a line is the commit its
# content was taken at, so a source's unrelated commits must not reach the lock
printf 'unrelated\n' >"$up/README"
git -C "$up" add README
git -C "$up" commit -qm unrelated
vsync update -u "$base" >/dev/null || fail "update failed on an unrelated commit in the source"
cmp -s "$work/lock.before" "$lock" || fail "update rewrote the lock for a source commit that touched nothing vendored"

# A vendored directory follows its source both ways
git -C "$up" rm -q data/b.txt
printf 'c\n' >"$up/data/c.txt"
git -C "$up" add -A
git -C "$up" commit -qm three
vsync update -u "$base" >/dev/null || fail "update failed on a directory whose source changed"
[ ! -e "$down/data/b.txt" ] || fail "a file deleted from a vendored directory's source stayed here"
[ -f "$down/data/c.txt" ] || fail "a file added to a vendored directory's source never arrived"
git -C "$down" add -A
git -C "$down" commit -qm synced

# An edit in place is named by check, and update refuses to run over it
printf 'edited here\n' >>"$down/tool.sh"
if out=$(vsync check 2>&1); then fail "check passed a copy edited in place"; fi
grep -q 'tool.sh' <<<"$out" || fail "check went red without naming the edited copy:"$'\n'"$out"
if vsync update -u "$base" >/dev/null 2>&1; then fail "update ran over a copy edited in place"; fi
grep -q 'edited here' "$down/tool.sh" || fail "update overwrote the edit it should have refused"
git -C "$down" checkout -q -- tool.sh
printf 'stray\n' >"$down/data/stray.txt"
if out=$(vsync check 2>&1); then fail "check passed a vendored directory with a file added in place"; fi
grep -q 'data/' <<<"$out" || fail "check went red without naming the edited directory:"$'\n'"$out"
rm -f "$down/data/stray.txt"
vsync check >/dev/null || fail "check stayed red after the edits were put back"

# A workflow file only as a manual line: the cascade's bot cannot push one
if vsync add -u "$base" .github/workflows/flow.yml owner/src flow.yml >/dev/null 2>&1; then
  fail "add took a workflow file without --manual, which the cascade's bot could never update"
fi
vsync add --manual -u "$base" .github/workflows/flow.yml owner/src flow.yml >/dev/null ||
  fail "add --manual could not take a workflow file"
printf 'on: [push]\n' >"$up/flow.yml"
git -C "$up" commit -qam four
vsync update -u "$base" >/dev/null || fail "update failed beside a manual line"
grep -qx 'on: push' "$down/.github/workflows/flow.yml" || fail "update without --manual touched a manual line"
vsync update --manual -u "$base" >/dev/null || fail "update --manual failed"
grep -qxF 'on: [push]' "$down/.github/workflows/flow.yml" || fail "update --manual did not bring a manual line"

# --manual refreshes the manual lines and nothing else: a person running it by hand must not
# land every other copy's new content without the verify step the weekly run gives it
printf '#!/bin/sh\necho three\n' >"$up/tool.sh"
printf 'on: [push, pull_request]\n' >"$up/flow.yml"
git -C "$up" commit -qam five
vsync update --manual -u "$base" >/dev/null || fail "update --manual failed"
grep -qxF 'on: [push, pull_request]' "$down/.github/workflows/flow.yml" || fail "update --manual did not bring the manual line"
grep -q 'echo two' "$down/tool.sh" || fail "update --manual also took a line that is not manual, without the verify step"
# And the weekly run names a manual copy that has fallen behind rather than skipping it in
# silence: nothing else would ever tell a person to refresh it
printf 'on: [workflow_dispatch]\n' >"$up/flow.yml"
git -C "$up" commit -qam six
out=$(vsync update -u "$base" 2>&1) || fail "update failed beside a manual line that is behind:"$'\n'"$out"
grep -qF '.github/workflows/flow.yml is behind' <<<"$out" ||
  fail "update did not name a manual copy that is behind its source:"$'\n'"$out"
grep -qxF 'on: [push, pull_request]' "$down/.github/workflows/flow.yml" || fail "update without --manual changed a manual line"

# The workflow guard is about where a file lands, however the path is spelled
if vsync add -u "$base" ./.github/workflows/flow2.yml owner/src flow.yml >/dev/null 2>&1; then
  fail "add took ./.github/workflows/flow2.yml without --manual — a leading ./ slipped past the guard"
fi
if vsync add -u "$base" .github/ owner/src data/ >/dev/null 2>&1; then
  fail "add took a directory at .github/ without --manual, which puts .github/workflows/ under an ordinary line"
fi

# A vendored directory is compared by name on both sides, so a name git would quote — here a
# Cyrillic one — must come out the same, and a symlink, which find and git see differently,
# is refused rather than left to read as an edit in place forever
mkdir -p "$up/names" "$up/links"
printf 'x\n' >"$up/names/файл.txt"
printf 'y\n' >"$up/names/plain.txt"
# git quotes a name with a double quote in it under any core.quotePath, so this one holds
# the proof on a machine whose git leaves non-ASCII names bare
printf 'w\n' >"$up/names/q\"uote.txt"
printf 'z\n' >"$up/links/real.txt"
ln -s real.txt "$up/links/alias.txt"
git -C "$up" add -A
git -C "$up" commit -qm names
vsync add -u "$base" names/ owner/src names/ >/dev/null || fail "add could not take a directory with a non-ASCII file name"
vsync check >/dev/null || fail "check rejected a directory with a non-ASCII file name right after taking it"
if vsync add -u "$base" links/ owner/src links/ >/dev/null 2>&1; then
  fail "add took a directory holding a symlink, which a copy cannot keep byte for byte"
fi

# vendor-sync.sh vendors itself, so an update rewrites the very script bash is executing.
# bash reads a script as it runs, so a copy rewritten in place makes the running update
# carry on from its old offset into whatever the new text holds there; a longer header
# in the new version is enough. The copy has to be replaced, not overwritten
cp templates/vendor-sync.sh "$up/vendor-sync.sh"
git -C "$up" add vendor-sync.sh
git -C "$up" commit -qm "vendor-sync itself"
vsync add -u "$base" vendor-sync.sh owner/src vendor-sync.sh >/dev/null ||
  fail "vendor-sync add could not take vendor-sync.sh itself"
{
  head -n 1 templates/vendor-sync.sh
  for i in $(seq 1 200); do printf '# a newer header, line %s, long enough to move every offset below it\n' "$i"; done
  tail -n +2 templates/vendor-sync.sh
} >"$up/vendor-sync.sh"
git -C "$up" commit -qam "a longer vendor-sync"
out=$(vsync update -u "$base" 2>&1) ||
  fail "update of vendor-sync.sh by itself failed:"$'\n'"$out"
[ "$(printf '%s\n' "$out" | grep -c '^vendor-sync: .* taken anew')" -eq 1 ] ||
  fail "update of vendor-sync.sh by itself did not finish exactly once:"$'\n'"$out"
cmp -s "$up/vendor-sync.sh" "$down/vendor-sync.sh" || fail "update left vendor-sync.sh different from its source"
vsync check >/dev/null || fail "check rejected vendor-sync.sh after it updated itself"

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
