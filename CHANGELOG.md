# Changelog

Kept in the shape of [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versioned by [semver](https://semver.org/spec/v2.0.0.html)

## [Unreleased]

## [1.0.0] - 2026-08-31

Extracted from [huix-standard](https://github.com/rokokol/huix-standard)'s CI conventions, generalized past the Nix family

### Added

- the rules: gate-or-detector separation with detectors off pull requests, everything pinned with a registry-lookup guard, a callable build workflow (`workflow_call` + `ref`) so bots verify with the real checks, the weekly bump→verify→land cascade, one badge per workflow file via reusable-plus-wrappers, falsifiable checks with self-tested checkers, one source of truth per list, and the VERSION↔CHANGELOG gate
- references for each rule and GitHub Actions templates (`build.yml`, `bump-cascade.yml`, `detector.yml` + wrapper) with `EXAMPLE` markers
- `check-templates.sh`: actionlint over the templates, proven able to fail against a known-bad fixture; the repo's own flake pins the toolbox
