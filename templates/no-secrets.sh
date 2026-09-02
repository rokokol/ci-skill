#!/usr/bin/env bash
# Refuse to ship a secret that slipped past .gitignore.
#
# .gitignore keeps a file out; this keeps a value out of a file that belongs
# here. Both are needed: the leak that matters is a token pasted into a config
# default, a doc or a fixture, not a stray file.
#
# THIS FILE IS A TEMPLATE, AND COPYING IT PROVES NOTHING. The patterns below are
# the part that knows what *this* repository's secrets look like, and the gate is
# worth having only once it has been falsified in its own repo: plant one value of
# each shape it claims to catch, see it red on every one, remove them. A gate that
# has only ever printed "clean" may simply be matching nothing.
set -euo pipefail

cd "$(dirname "$0")/.."

fail=0
report() {
  printf 'secret-gate: %s\n' "$1" >&2
  fail=1
}

# Tracked files only — an untracked scratch file is not about to be pushed.
# -I skips binaries, so a matching byte sequence in an image is not a finding
mapfile -t tracked < <(git ls-files)
[[ ${#tracked[@]} -gt 0 ]] || {
  echo "secret-gate: nothing tracked yet" >&2
  exit 0
}

# Shapes worth checking in any repository
if git grep -nIE 'BEGIN (OPENSSH|RSA|EC|PGP) PRIVATE KEY' -- "${tracked[@]}" >&2; then
  report "private key material"
fi

if git grep -nIE '(github_pat_|ghp_|gho_|ghs_)[A-Za-z0-9_]{20,}' -- "${tracked[@]}" >&2; then
  report "GitHub token"
fi

# A real value assigned to a secret-shaped key, in either an assignment or a
# mapping. The allow-list is what keeps documented examples legal — and it is
# also the line to re-read when a real leak is reported as clean
if git grep -nIE '^[[:space:]]*"?(token|password|secret|api_key|auth_key|authkey)"?[[:space:]]*[=:][[:space:]]*"[^"]{8,}"' \
  -- "${tracked[@]}" | grep -vE '(replace-me|example|CHANGEME|test-|\{\{)' >&2; then
  report "literal secret assignment"
fi

# >>> EXAMPLE: the shapes only this repository can leak — a service's session
# cookie, a provider's key prefix, a subscription URL. One branch each, so the
# message names what was found rather than "something matched"
if git grep -nIE 'SERVICE=[A-Za-z0-9+/_=-]{40,}' -- "${tracked[@]}" >&2; then
  report "service session cookie"
fi
# <<<

# >>> EXAMPLE: whole paths that must never be tracked at all, whatever they hold —
# the credential store, a private registry, a downloaded database
if git ls-files | grep -qE '^secrets/'; then
  report "a file under secrets/ is tracked; that directory is the credential store"
fi

if git ls-files | grep -qE '\.db$'; then
  report "a database is tracked"
fi
# <<<

[[ $fail -eq 0 ]] && echo "secret-gate: clean"
exit "$fail"
