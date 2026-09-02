#!/usr/bin/env bash
# Prints one line per shape templates/no-secrets.sh claims to catch, so
# check-templates.sh can plant them in a throwaway repository and require the
# gate to go red on every one.
#
# The bodies are GENERATED rather than written out, and that is deliberate: a
# literal key-shaped string committed here would be a real finding for every
# scanner that looks at this repository — GitHub's push protection included —
# and a fixture that cannot be pushed is not a fixture. What is committed is
# the prefix alone, which matches nothing on its own.
set -euo pipefail

rep() { # rep CHAR COUNT
  printf "%${2}s" '' | tr ' ' "$1"
}

# private key material
echo "-----BEGIN OPENSSH PRIVATE KEY-----"
echo "-----BEGIN PRIVATE KEY-----"

# forge and registry tokens
echo "ghp_$(rep A 32)"
echo "github_pat_$(rep A 62)"
echo "glpat-$(rep A 22)"
echo "npm_$(rep A 36)"
echo "pypi-$(rep A 52)"
echo "hf_$(rep A 32)"
echo "dckr_pat_$(rep A 22)"

# model-provider keys
echo "sk-ant-api03-$(rep A 90)"
echo "sk-proj-$(rep A 24)"
echo "sk-svcacct-$(rep A 24)"
echo "sk-or-v1-$(rep a 64)"
echo "sk-$(rep A 48)"
echo "AIza$(rep A 35)"
echo "gsk_$(rep A 52)"
echo "r8_$(rep A 36)"

# cloud and SaaS credentials
echo "AKIA$(rep Q 16)"
echo "GOCSPX-$(rep A 28)"
echo "xoxb-$(rep A 12)"
echo "https://hooks.slack.com/services/$(rep A 24)"
echo "sk_live_$(rep A 24)"
echo "SG.$(rep A 22).$(rep A 43)"
echo "key-$(rep a 32)"
echo "AC$(rep a 32)"
echo "dop_v1_$(rep a 64)"
echo "dp.pt.$(rep A 44)"
echo "lin_api_$(rep A 44)"
echo "$(rep 1 9):AA$(rep A 33)"

# a signed token pasted whole
echo "eyJ$(rep A 12).eyJ$(rep A 12).$(rep A 12)"

# a real value on a secret-shaped key
echo "api_key = \"$(rep Z 20)\""
