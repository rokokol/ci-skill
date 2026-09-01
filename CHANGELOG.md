# Changelog

Kept in the shape of [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versioned by [semver](https://semver.org/spec/v2.0.0.html)

## [Unreleased]

### Added

- bump-cascade reference: what to do when the bot lands a bump under you — rebase, re-verify on the fresh lock, never force-push over it; and ops reference: when local and CI disagree, suspect the observer's network (a container bridge bypassing a VPN, a geo-blocking CDN) before the check
- workflows reference: "the runner is not a target environment" — a job exercising the install/deploy path supplies its own pinned dependencies, and a preflight refusing the runner is working as designed; plus "anything that can wait for input gets a timeout", after a provider-selection menu rejected a script's `y` and hung until the platform killed it

## [1.0.0] - 2026-08-31

Extracted from [huix-standard](https://github.com/rokokol/huix-standard)'s CI conventions, generalized past the Nix family

### Added

- the rules: gate-or-detector separation with detectors off pull requests, everything pinned with a registry-lookup guard, a callable build workflow (`workflow_call` + `ref`) so bots verify with the real checks, the weekly bump→verify→land cascade, one badge per workflow file via reusable-plus-wrappers, falsifiable checks with self-tested checkers, one source of truth per list, and the VERSION↔CHANGELOG gate
- references for each rule and GitHub Actions templates (`build.yml`, `bump-cascade.yml`, `detector.yml` + wrapper) with `EXAMPLE` markers
- `check-templates.sh`: actionlint over the templates, proven able to fail against a known-bad fixture; the repo's own flake pins the toolbox
- `ci.sh`, the operational harness: `status`/`runs`/`watch`/`failed`/`dispatch`/`rerun` over gh — `failed` names the failing steps and strips the runner's teardown noise that buries the real error in a raw log tail
