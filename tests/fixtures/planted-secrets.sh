#!/usr/bin/env bash
# Prints one line per shape templates/no-secrets.sh claims to catch — the gate's own
# name for the shape, a tab, a value of that shape — so check-templates.sh can plant
# each in a throwaway repository and require the gate to go red on it, naming that
# shape and not another: a value caught by the wrong pattern means the right one is dead.
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

plant() { # plant SHAPE VALUE — SHAPE is the message no-secrets.sh reports it under
  printf '%s\t%s\n' "$1" "$2"
}

plant "private key material" "-----BEGIN OPENSSH PRIVATE KEY-----"
plant "private key material" "-----BEGIN PRIVATE KEY-----"

plant "forge or registry token" "ghp_$(rep A 32)"
plant "forge or registry token" "github_pat_$(rep A 62)"
plant "forge or registry token" "glpat-$(rep A 22)"
plant "forge or registry token" "npm_$(rep A 36)"
plant "forge or registry token" "pypi-$(rep A 52)"
plant "forge or registry token" "hf_$(rep A 32)"
plant "forge or registry token" "dckr_pat_$(rep A 22)"

plant "model-provider API key" "sk-ant-api03-$(rep A 90)"
plant "model-provider API key" "sk-proj-$(rep A 24)"
plant "model-provider API key" "sk-svcacct-$(rep A 24)"
plant "model-provider API key" "sk-or-v1-$(rep a 64)"
plant "model-provider API key" "sk-$(rep A 48)"
plant "model-provider API key" "AIza$(rep A 35)"
plant "model-provider API key" "gsk_$(rep A 52)"
plant "model-provider API key" "r8_$(rep A 36)"

plant "cloud or SaaS credential" "AKIA$(rep Q 16)"
plant "cloud or SaaS credential" "GOCSPX-$(rep A 28)"
plant "cloud or SaaS credential" "xoxb-$(rep A 12)"
plant "cloud or SaaS credential" "https://hooks.slack.com/services/$(rep A 24)"
plant "cloud or SaaS credential" "sk_live_$(rep A 24)"
plant "cloud or SaaS credential" "SG.$(rep A 22).$(rep A 43)"
plant "cloud or SaaS credential" "key-$(rep a 32)"
plant "cloud or SaaS credential" "AC$(rep a 32)"
plant "cloud or SaaS credential" "dop_v1_$(rep a 64)"
plant "cloud or SaaS credential" "dp.pt.$(rep A 44)"
plant "cloud or SaaS credential" "lin_api_$(rep A 44)"
plant "cloud or SaaS credential" "$(rep 1 9):AA$(rep A 33)"

plant "JWT-shaped token" "eyJ$(rep A 12).eyJ$(rep A 12).$(rep A 12)"

plant "literal secret assignment" "api_key = \"$(rep Z 20)\""
