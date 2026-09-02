# Changelog

Kept in the shape of [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), dated rather than numbered — a skill is read at whatever revision you have checked out, so there is no version to bump

## Unreleased

### Changed

- the skill is `ci` and its repository `ci-skill`, following the family's `<name>` / `<name>-skill` split

### Removed

- the `VERSION` file and the self-applied VERSION↔CHANGELOG step: a skill is read at whatever revision is checked out, so it has no version to be wrong about — checks.md now says which repos the gate is for, and this changelog is dated rather than numbered

### Added

- `templates/falsify.py` and `templates/no-secrets.sh`, the two reusable checkers, generalized from 3x-ui-admin-skill and skibidi-vpn where both found real bugs — mechanism only, with the defect list and the secret shapes left as `EXAMPLE` markers, and a header on each saying that a copy must be falsified in its own repository
- checks reference: a section on both checkers — why the falsifier restores from memory rather than git, why an exactly-once `find` reports `stale` instead of guessing, why a suite already red aborts it, and why the secret gate greps tracked files only
- `tests/fixtures/unpinned-workflow.yml` and a check-templates step proving the pin guard can fail: the pattern is read out of the build template (never spelled twice), must match the fixture, and must not match the template carrying it — both halves watched failing

### Changed

- the pin guard now covers `npx`, `pip install` and `go install …@latest` beside the nix lookups, in self-match-safe form (`pip +install `, `npx +[a-z@.-]`) — the template and pinning.md had drifted apart, and the reference's own example was the unsafe spelling
- the flake's toolbox gained pyflakes, and check-templates lints both checker templates

- bump-cascade reference: what to do when the bot lands a bump under you — rebase, re-verify on the fresh lock, never force-push over it; and ops reference: when local and CI disagree, suspect the observer's network (a container bridge bypassing a VPN, a geo-blocking CDN) before the check
- workflows reference: "the runner is not a target environment" — a job exercising the install/deploy path supplies its own pinned dependencies, and a preflight refusing the runner is working as designed; plus "anything that can wait for input gets a timeout", after a provider-selection menu rejected a script's `y` and hung until the platform killed it

## 2026-08-31

Extracted from [huix-standard](https://github.com/rokokol/huix-standard-skill)'s CI conventions, generalized past the Nix family

### Added

- the rules: gate-or-detector separation with detectors off pull requests, everything pinned with a registry-lookup guard, a callable build workflow (`workflow_call` + `ref`) so bots verify with the real checks, the weekly bump→verify→land cascade, one badge per workflow file via reusable-plus-wrappers, falsifiable checks with self-tested checkers, one source of truth per list, and the VERSION↔CHANGELOG gate
- references for each rule and GitHub Actions templates (`build.yml`, `bump-cascade.yml`, `detector.yml` + wrapper) with `EXAMPLE` markers
- `check-templates.sh`: actionlint over the templates, proven able to fail against a known-bad fixture; the repo's own flake pins the toolbox
- `ci.sh`, the operational harness: `status`/`runs`/`watch`/`failed`/`dispatch`/`rerun` over gh — `failed` names the failing steps and strips the runner's teardown noise that buries the real error in a raw log tail
