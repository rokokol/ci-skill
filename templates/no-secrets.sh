#!/usr/bin/env bash
# Refuse to ship a secret that slipped past .gitignore.
#
# .gitignore keeps a file out; this keeps a value out of a file that belongs
# here. Both are needed: the leak that matters is a token pasted into a config
# default, a doc or a fixture, not a stray file.
#
# THIS FILE IS A TEMPLATE, AND COPYING IT PROVES NOTHING. The provider shapes
# below are worth having anywhere; the last two sections are the part that knows
# what *this* repository's secrets look like, and the gate is worth having only
# once it has been falsified in its own repo: plant one value of each shape it
# claims to catch, see it red on every one, remove them. A gate that has only
# ever printed "clean" may simply be matching nothing.
#
# Every pattern is written so it cannot match its own source line — a literal
# prefix is always followed by a bracket expression, which the pattern text
# itself does not satisfy. Keep that property when adding one, or the gate
# reddens the repository on the commit that introduces it.
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

scan() { # scan DESCRIPTION ERE
  if git grep -nIE "$2" -- "${tracked[@]}" >&2; then
    report "$1"
  fi
}

# Any PEM private key, whatever the algorithm label says
scan "private key material" \
  'BEGIN ([A-Z]+ )*PRIVATE KEY'

# Forges and package registries — the tokens that let someone push as you
scan "forge or registry token" \
  '(gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{60,}|glpat-[A-Za-z0-9_-]{20,}|npm_[A-Za-z0-9]{36}|pypi-[A-Za-z0-9_-]{50,}|hf_[A-Za-z0-9]{30,}|dckr_pat_[A-Za-z0-9_-]{20,})'

# Model providers. Anthropic and OpenAI both start sk-, and both are billed per
# token by whoever holds the string
scan "model-provider API key" \
  '(sk-ant-[a-z0-9]+-[A-Za-z0-9_-]{80,}|sk-proj-[A-Za-z0-9_-]{20,}|sk-svcacct-[A-Za-z0-9_-]{20,}|sk-or-v1-[0-9a-f]{60,}|sk-[A-Za-z0-9]{48}|AIza[A-Za-z0-9_-]{35}|gsk_[A-Za-z0-9]{50,}|r8_[A-Za-z0-9]{35,})'

# Cloud and SaaS. An AWS key id is worth catching even alone: it names the
# account, and the matching secret is usually one line below
scan "cloud or SaaS credential" \
  '((AKIA|ASIA|ABIA|ACCA)[0-9A-Z]{16}|GOCSPX-[A-Za-z0-9_-]{28}|xox[abposr]-[0-9A-Za-z-]{10,}|hooks\.slack\.com/services/[A-Za-z0-9/]{20,}|(sk|rk)_live_[0-9A-Za-z]{20,}|SG\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{40,}|key-[0-9a-f]{32}|AC[0-9a-f]{32}|dop_v1_[0-9a-f]{60,}|dp\.pt\.[A-Za-z0-9]{40,}|lin_api_[A-Za-z0-9]{40,}|[0-9]{8,10}:AA[A-Za-z0-9_-]{33})'

# A signed token pasted whole — a Supabase service key, a session bearer, an
# identity assertion. Three base64url segments, the first two decoding to JSON
scan "JWT-shaped token" \
  'eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'

# A real value assigned to a secret-shaped key, in either an assignment or a
# mapping — the catch-all for providers with no distinctive prefix. The
# allow-list is what keeps documented examples legal, and it is also the line
# to re-read when a real leak is reported as clean
if git grep -nIE '^[[:space:]]*"?(token|password|passwd|secret|api_key|apikey|auth_key|authkey|access_key|private_key|client_secret)"?[[:space:]]*[=:][[:space:]]*"?[^"[:space:]]{12,}' \
  -- "${tracked[@]}" | grep -vE '(replace-me|example|CHANGEME|changeme|placeholder|your-|test-|dummy|xxx|\$\{|\{\{|<[a-z-]+>)' >&2; then
  report "literal secret assignment"
fi

# >>> EXAMPLE: the shapes only this repository can leak — a service's session
# cookie, a subscription URL, an internal hostname. One scan each, so the
# message names what was found rather than "something matched"
scan "service session cookie" \
  'SERVICE=[A-Za-z0-9+/_=-]{40,}'
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
