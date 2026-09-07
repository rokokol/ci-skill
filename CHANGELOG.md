# Changelog

Kept in the shape of [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), dated rather than numbered, and with no `Unreleased` section — a skill is read at whatever revision you have checked out, so whatever is on the default branch is what every reader already has, and a section for work that has landed but not shipped would never close. The reasoning is in [references/checks.md](references/checks.md), which owns the rule about what has no version

## 2026-09-07

### Added

- the rule that a push is not done until its runs conclude: run the gate locally with the workflow's own command first, push, `ci.sh watch` to a verdict, report the verdict rather than the push, and on red `ci.sh failed` and a fix — with `ci.sh rerun` reserved for an external cause that has been named. The harness had the commands and ops.md called `watch` "the after-push command", but nothing said that a push without it is unfinished; ops.md now carries the ritual in full

- `templates/check-pins.sh`, the pin guard as one file that travels, replacing the inline grep every build workflow re-typed. The grep had already drifted: the repository the rule came from carried only the `nix run` alternative, two others the full pattern, `pinning.md` a third spelling, and a dozen more repositories a copy each — so widening it meant editing all of them, and it was not widened. The script scans a directory of workflows, exits 2 when it finds none to scan, skips comments and lines marked `# check-pins: allow`, and covers `nix run`/`shell nixpkgs#`, `npx` (with `--no-install` pinned), `pip`/`pip3`/`-m pip install`, `pipx`, `uvx` and `uv tool run`, `go install @latest`, `cargo install` without `--locked`, `curl`/`wget | sh`, and `uses: @main`/`@master`/`@latest`. On every run it plants each of those fourteen shapes alone in a throwaway workflow and requires a finding quoting it, then six pinned spellings together and requires quiet, then an empty directory and requires a refusal. The build template's guard step calls it; this repository's `ci.yml` drops its inline copy, since `check-templates.sh` runs the guard on `.github/workflows` and the workflow templates; `tests/fixtures/unpinned-workflow.yml` goes, its shapes now living in the script

### Changed

- the skill's description names the moments it was missing: checking CI rather than only writing or reviewing it, pushing to a repository that has CI and following the runs afterwards, and asking whether a run passed or why it went red — with the Russian phrasings beside the English ones. A skill is loaded by its description, and one that only mentions writing CI is not reached for when the question is whether the last push went green
- `templates/check-skill.sh` is one self-contained gate rather than a skeleton, and is now actually runnable: the previous version called a `tests/check-links.sh` and a `broken-links.md` fixture that were never shipped, so a copy died on its first run — and nothing here caught that, because the template was linted but never executed. The new file takes the repository as an argument (`check-skill.sh [-n NAME] [DIR]`), so it is copied verbatim and called from a repo's own gate, and it needs bash 3.2 and POSIX tools only. Its reachability check is now a real walk: only a link counts, not a mention of a basename in prose; reachability is transitive from SKILL.md through the references, and README.md and CHANGELOG.md are not hops, since an agent does not load them. Its frontmatter check now enforces what the loader enforces — a name of lowercase letters, digits and single hyphens up to 64 characters, a description up to 1024 characters counted as characters, a closed frontmatter block. Its anchor check slugs headings the way GitHub does, Unicode dashes and quotes dropped and duplicates suffixed, and ignores links inside code fences and code spans. And it falsifies itself on every run: nine planted defects, each required to go red for its own reason, plus two controls
- `check-templates.sh` runs the skill gate on this repository's own docs, which is at once the gate on them and the proof that the template works; requires the pin guard's pattern to match every step of `tests/fixtures/unpinned-workflow.yml` on its own, since one live alternative kept the fixture red while the others could have been dead; and requires the secret gate to report each planted shape under that shape's own name, which the old "it went red" check did not — `tests/fixtures/planted-secrets.sh` now emits the name beside the value

## 2026-09-05

### Removed

- the version-and-changelog rules, to the [versioning](https://github.com/rokokol/versioning-skill) skill, which owns that question whole: where a version lives, which repositories have one at all, what a changelog looks like in either case, what earns an entry, and how a release is cut. This skill had grown a presentation topic inside a section about lists, which is both the wrong home and impossible to find. What stays here is the CI fact — the check is a gate on pull requests for repos that ship a version — plus a pointer in the build template, spelled inline because a workflow cannot assume another repository is checked out
- `templates/falsify.py`, and the account of falsification in `references/checks.md`. Asking whether a *test suite* would notice the code breaking is the [tests](https://github.com/rokokol/tests-skill) skill's subject, and its `t.sh falsify` does the same job across languages rather than only in Python — build and test as separate phases, so an edit the compiler rejects is reported `unusable` instead of being credited to the suite. What stays here is one link: two accounts of one thing disagree within a month. The flake's toolbox loses `pyflakes` with it

### Added

- the rule that a versionless repository's changelog carries no `Unreleased` section either — written here first, then moved to the versioning skill along with the rest of the topic the same day

## 2026-09-04

### Added

- `templates/check-skill.sh`, the gate a skill repository needs, taken from one where each of its checks had to catch something real. A skill fails in ways no test in the repository it documents would notice: malformed frontmatter and the agent never loads the file at all, a reference nothing links to rots unread while looking maintained, a moved heading leaves a link that resolves to nothing for a reader who is not there to complain. Each half is then made to fail on purpose in a throwaway copy

## 2026-09-02

### Added

- `templates/falsify.py` and `templates/no-secrets.sh`, the two reusable checkers, generalized from 3x-ui-admin-skill and skibidi-vpn where both found real bugs — mechanism only, with the defect list and the secret shapes left as `EXAMPLE` markers, and a header on each saying that a copy must be falsified in its own repository
- checks reference: a section on both checkers — why the falsifier restores from memory rather than git, why an exactly-once `find` reports `stale` instead of guessing, why a suite already red aborts it, and why the secret gate greps tracked files only
- `tests/fixtures/unpinned-workflow.yml` and a check-templates step proving the pin guard can fail: the pattern is read out of the build template (never spelled twice), must match the fixture, and must not match the template carrying it — both halves watched failing
- the secret gate template covers the shapes worth catching anywhere: PEM private keys of any algorithm, forge and registry tokens, model-provider keys (Anthropic, OpenAI project and service accounts, OpenRouter, Google, Groq, Replicate), cloud and SaaS credentials (AWS key ids, Slack tokens and webhooks, Stripe, SendGrid, Mailgun, Twilio, DigitalOcean, Doppler, Linear, Telegram) and anything JWT-shaped, under a widened catch-all for keys with no distinctive prefix
- `tests/fixtures/planted-secrets.sh` and the check-templates step that runs the gate end to end in a throwaway repository — clean on its own source, then red on each of 31 planted shapes in turn, one tracked file at a time so an over-broad pattern cannot cover for a dead one. The planted bodies are generated rather than committed: a literal key-shaped string in a fixture is a real finding for every scanner reading the repo

### Changed

- the skill is `ci` and its repository `ci-skill`, following the family's `<name>` / `<name>-skill` split
- the pin guard now covers `npx`, `pip install` and `go install …@latest` beside the nix lookups, in self-match-safe form (`pip +install `, `npx +[a-z@.-]`) — the template and pinning.md had drifted apart, and the reference's own example was the unsafe spelling
- the flake's toolbox gained pyflakes, and check-templates lints both checker templates

### Removed

- the `VERSION` file and the self-applied VERSION↔CHANGELOG step: a skill is read at whatever revision is checked out, so it has no version to be wrong about — checks.md now says which repos the gate is for, and this changelog is dated rather than numbered

## 2026-09-01

### Added

- `ci.sh`, the operational harness: status, runs, watch, failed, dispatch, rerun

### Changed

- bump-cascade reference: what to do when the bot lands a bump under you — rebase, re-verify on the fresh lock, never force-push over it; and ops reference: when local and CI disagree, suspect the observer's network (a container bridge bypassing a VPN, a geo-blocking CDN) before the check
- workflows reference: "the runner is not a target environment" — a job exercising the install/deploy path supplies its own pinned dependencies, and a preflight refusing the runner is working as designed; plus "anything that can wait for input gets a timeout", after a provider-selection menu rejected a script's `y` and hung until the platform killed it

## 2026-08-31

Extracted from [huix-standard](https://github.com/rokokol/huix-standard-skill)'s CI conventions, generalized past the Nix family

### Added

- the rules: gate-or-detector separation with detectors off pull requests, everything pinned with a registry-lookup guard, a callable build workflow (`workflow_call` + `ref`) so bots verify with the real checks, the weekly bump→verify→land cascade, one badge per workflow file via reusable-plus-wrappers, falsifiable checks with self-tested checkers, one source of truth per list, and the VERSION↔CHANGELOG gate
- references for each rule and GitHub Actions templates (`build.yml`, `bump-cascade.yml`, `detector.yml` + wrapper) with `EXAMPLE` markers
- `check-templates.sh`: actionlint over the templates, proven able to fail against a known-bad fixture; the repo's own flake pins the toolbox
- `ci.sh`, the operational harness: `status`/`runs`/`watch`/`failed`/`dispatch`/`rerun` over gh — `failed` names the failing steps and strips the runner's teardown noise that buries the real error in a raw log tail
