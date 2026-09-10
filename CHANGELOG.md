# Changelog

Kept in the shape of [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), dated rather than numbered, and with no `Unreleased` section — a skill is read at whatever revision you have checked out, so whatever is on the default branch is what every reader already has, and a section for work that has landed but not shipped would never close. The rule lives in the [versioning](https://github.com/rokokol/versioning-skill) skill, which owns what has no version

## 2026-09-10

### Added

- a section in `check-templates.sh` that reads the subcommands from `ci.sh`'s own dispatch and fails when the README's table, `references/ops.md`'s table or either layout line leaves one out, so the omission below cannot recur in silence. It proves itself on every run against a copy of `ops.md` with its `log` row removed, and it refuses to pass when it reads no subcommand at all — which is how its first draft, matching the wrong indentation, was caught before it could pass on nothing
- **`templates/vendor-sync.sh` and `templates/github/workflows/vendor-sync.yml`**: the vendoring cascade. A file another repository needs stays there as a verbatim copy, listed in `.github/vendor.lock` with the commit it came from and the blob it must still be; `check` is offline and fails the gate on a copy edited in place, `update` takes each source's current content, and the weekly workflow lands it through the repository's own build workflow only on green. Workflow files are taken with `--manual`, because the token a workflow runs with cannot push one. The tool vendors itself, and replaces a copy rather than rewriting it, since bash would carry on into the new text of a script rewritten while it runs. `references/bump-cascade.md` describes it once, in "Vendored files", and every file that travels says so in its header

### Changed

- the description sat at exactly the 1024 characters an agent reads, so any trigger added to it would have been cut; a trigger listed twice is gone, leaving room
- `check-pins.sh` and `check-skill.sh` are no longer "copied verbatim": their headers, `SKILL.md`, the readme, `references/pinning.md` and `references/checks.md` send a repository to the vendoring cascade instead
### Fixed

- **`ci.sh log`, added on 2026-09-08, was missing from every place that lists the harness**: the layout in `SKILL.md`, the README's table and layout, and the table in `references/ops.md`, whose introduction called the list "the same six questions". An agent learning the harness from its documentation had no way to find it
- counts written into prose beside the list they count — "Three reusable checkers", "the four workflow files", "the other two below", and the pin guard's and the secret gate's shape counts in the README — each a second copy of a length that lives in the list or the script, one of them already wrong
- a trailing full stop on every rule in `SKILL.md`, against the rule every readme in the family is held to
- **`check-pins.sh` proved fewer shapes than it claimed.** Four alternatives of its pattern — `pip3 install`, `pipx install`, `npx --yes` and an action at `@main` or `@latest` — had no planted example, so narrowing any of them left the self-test green; a lone planted line going red only proved that something matched it. The shapes are now a list of pairs, each shape written once beside the line it must catch, every example must match its own shape, and the scan pattern is that list joined
- `check-skill.sh -n` with no name exited 1 with bash's own message, where its header promises 2 for a usage error; and `--help` in both checkers printed a fixed line range the header had outgrown, dropping the exit codes from one and the `# check-pins: allow` marker from the other. Both are now held by `check-templates.sh`, and the planted-defect count in `check-skill.sh` is kept by the one function every planted case goes through

## 2026-09-08

### Fixed

- **`ci.sh failed` could not see the run that mattered.** It selected on `conclusion == "failure"`, and GitHub does not use that word for a job killed by `timeout-minutes`: such a job concludes `cancelled`, a runner that never came up `startup_failure`, and `timed_out` exists as well. A gate cancelled at its job timeout therefore printed nothing here — and exited nonzero while printing it, because the empty log went through a `grep -v` under `pipefail`, which reads as a broken reader rather than as a blind one. `failed` now takes anything that concluded and was not a success, names the job with its conclusion and the steps that went wrong, and falls back from `--log-failed`, which has nothing to give for a cancelled job, to the whole log of each job that went wrong. A run where nothing went wrong is said out loud, because silence there was indistinguishable from the bug

### Added

- **`ci.sh log [RUN_ID] [JOB]`**, the whole log of one job whatever it concluded. `failed` cannot give it: a job that passed has no failing step, and the first green run of a job that has never run before — a new macOS matrix leg, say — is exactly the one worth reading rather than trusting. The job is named, or inferred when the run has only one, and a wrong name is answered with the names the run does have
- **`ci.sh` is checked, not only linted.** The tool this skill hands out for reading CI had nothing behind it but `shellcheck` and `shfmt`, and both of the entries above were found by using it rather than by testing it. `check-templates.sh` now drives it against a stub `gh` that answers from real captures of two runs of another repository, one cancelled at its job timeout and one green, so the subject is `ci.sh`'s own logic and no network is involved. The stub errors on any call `ci.sh` does not make, so a check cannot pass because the fake quietly returned nothing

## 2026-09-07

### Added

- `templates/no-secrets.sh` now rejects tracked paths matched by `.gitignore`, catching artifacts admitted with `git add -f` without objecting to `.gitignore` itself; `check-templates.sh` proves it on `user/preferences.md` in a throwaway repository and requires the finding to name that path

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
