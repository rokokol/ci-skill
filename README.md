<div align="center">

# CI skill

**CI that stays green for the right reasons (￣ー￣)ゞ**

[![Agent Skill](https://img.shields.io/badge/Agent_Skill-6E56CF?style=flat)](https://agentskills.io)
![GitHub Actions](https://img.shields.io/badge/GitHub-Actions-2088FF?style=flat&logo=githubactions&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=flat&logo=gnubash&logoColor=white)
![Nix](https://img.shields.io/badge/Nix-flake-7EBAE4?style=flat&logo=nixos&logoColor=white)
[![license](https://img.shields.io/badge/MIT-3DA639?style=flat)](LICENSE)
[![ci](https://github.com/rokokol/ci-skill/actions/workflows/build.yml/badge.svg)](https://github.com/rokokol/ci-skill/actions/workflows/build.yml)

</div>

A green pipeline is worth exactly as much as the question it answers. A check that cannot fail answers nothing, a job that goes red without a code change answers about someone else's mirror, and a badge people have learned to re-run answers about their patience. This skill is the set of rules that keep those three from happening, plus the templates and the terminal harness that make following them the cheap path

It teaches an agent to write and review CI: what may gate a pull request and what has to stay a weekly drift detector, why every binary a job runs comes from the repo's own lockfile, how dependency bumps land themselves without a human babysitting them, how a readme earns one honest badge per statement, and why a checker that has never been red is a decoration

Extracted from **[huix-standard](https://github.com/rokokol/huix-standard-skill)**, where every rule below was paid for by a real red run — this is the provider-general half, so nothing here assumes Nix or any language, though the templates are GitHub Actions

## Contents

- [Install](#install)
- [The rules](#the-rules)
- [The harness](#the-harness)
- [Templates](#templates)
- [Tests](#tests)
- [Layout](#layout)

## Install

```sh
git clone https://github.com/rokokol/ci-skill ~/Projects/ci
ln -s ~/Projects/ci ~/.claude/skills/ci
```

Or straight into the skills directory your agent reads:

```sh
git clone https://github.com/rokokol/ci-skill ~/.claude/skills/ci
```

> [!NOTE]
> A skill has no version to pin — it is read at whatever revision you have checked out, so `git pull` is the whole upgrade path and the changelog is dated rather than numbered

Then ask Claude Code to write, review or check CI, push to a repository that has it, or reach for it by name. [SKILL.md](SKILL.md) carries the rules, `references/` the reasoning behind each, `templates/` the copyable workflow files with `EXAMPLE` markers where a repo has to fill in its own

## The rules

| | |
|---|---|
| **[Gate or detector, never both](references/badges.md)** | Checks that depend only on the repo gate pull requests. Checks that depend on someone else's uptime — mirrors, `:latest` images, live sites — run on push, on a weekly cron and by hand, **never on PRs**: a Debian mirror having an afternoon must not redden someone's rename, and the weekly run is the drift alarm those checks exist to be |
| **[Everything pinned](references/pinning.md)** | Actions by version under dependabot, tools from the repo's own lockfile — `nix develop`, `npm ci`, `cargo --locked` — never `nix run nixpkgs#tool`, `npx tool@latest`, `pip install tool`. An unpinned lookup is a mirror-fate test: the job changes behaviour with zero change in the repo. `check-pins.sh`, one file vendored into every repository that runs it, greps the workflows and fails on it, proving per shape on every run that it can |
| **[The build workflow is callable](references/workflows.md)** | `workflow_call` with a `ref` input, so bots verify a branch by running *the real workflow* instead of a copy of its commands that drifts away from it |
| **[Bumps land themselves, on green](references/bump-cascade.md)** | A weekly bump→verify→land cascade: bump onto a dated branch, verify by calling the build workflow against it, fast-forward and delete only on green — red leaves the branch standing for a human |
| **[A file that travels is vendored](references/bump-cascade.md#vendored-files)** | A checker another repository needs is a verbatim copy there, listed in a lock with the commit it came from and the blob it must still be. The gate refuses a copy edited in place, and a weekly cascade of the same shape takes each source's newer content, so a fix made once reaches every copy |
| **[One badge per statement](references/badges.md)** | A status badge is per workflow *file*, so anything deserving its own badge gets a thin wrapper delegating to one reusable job. The wrappers differ by name and input; the logic lives once |
| **[Every check is proven able to fail](references/checks.md)** | A new check runs red first — against the pre-fix state or a deliberately broken fixture. Checkers ship self-tests against known-bad inputs, and assertions on generated text match whole lines, not substrings. The same question about a *test suite* belongs to the [tests](https://github.com/rokokol/tests-skill) skill |
| **[One source of truth per list](references/checks.md)** | Lint file lists, tool sets, version numbers — each lives in exactly one place the others read. Duplicated lists drift, and drifted lists lie. Where the version lives, and what a changelog looks like with or without one, belongs to the [versioning](https://github.com/rokokol/versioning-skill) skill |
| **Least privilege, bounded time** | `permissions: contents: read` at every workflow's top, widened per job only where a job writes; `timeout-minutes` on anything that talks to the network or can wait for input; `concurrency` on anything that pushes |
| **[A push is not done until its runs conclude](references/ops.md)** | Run the gate locally with the workflow's own command first, push, then `ci.sh watch` to a verdict — and report the verdict, not the push. Red means `ci.sh failed` and a fix; a rerun is for an external cause that has been named |

## The harness

[`ci.sh`](ci.sh) is the operational half — the questions you would otherwise re-derive from `gh run` flags every time:

| Command | What it answers |
|---|---|
| `ci.sh status` | the badge row in a terminal: every workflow's latest run, one line each |
| `ci.sh runs [N]` | the recent runs with their ids, for picking a target |
| `ci.sh watch` | blocks until every run of the current HEAD concludes, nonzero if any failed — the after-push command |
| `ci.sh failed [ID]` | which steps failed, then the log around the real error |
| `ci.sh log [ID] [JOB]` | the whole log of one job, whatever it concluded — the first green run of a new job is the one worth reading rather than trusting |
| `ci.sh dispatch WF [REF]` | fire a `workflow_dispatch` and follow it to a verdict |
| `ci.sh rerun [ID]` | rerun a run's failed jobs and follow |

Every subcommand takes `-R owner/repo` to aim at another repository; without it, `gh`'s own default applies. `ci.sh failed` exists because `gh run view --log-failed` ends each job with the runner's teardown — credential unsets, orphan reaping — dozens of lines that bury the error, and on a multi-job run the tail you land on is often the wrong job's

## Templates

`templates/github/workflows/` holds the workflow files the rules describe, and beside them the checkers worth having in any repository:

```
github/workflows/
  build.yml            the gate: workflow_call + ref, calls the pin guard, least privilege
  bump-cascade.yml     weekly bump -> verify by calling build.yml -> land on green
  detector.yml         the reusable world-facing job
  detector-target.yml  the thin wrapper that gives that job its own badge
  vendor-sync.yml      weekly refresh of vendored files -> verify by calling build.yml -> land on green
no-secrets.sh          refuse ignored paths and secret values at the tracked-file boundary
check-pins.sh          the pin guard: no tool from a registry, proven per shape on every run
check-skill.sh         the gate a skill repository needs, falsifying itself on every run
vendor-sync.sh         keep vendored copies byte-equal to their source, and refuse an edit in place
```

`no-secrets.sh` rejects tracked paths matched by `.gitignore`, including paths admitted with `git add -f`, before scanning tracked contents for secret shapes; `.gitignore` itself remains ordinary repository content. `EXAMPLE` markers sit on everything repo-specific — the bump command, what the detector probes, the secret shapes only your repo can leak. The other checkers have no such part, and another repository takes them through the [vendoring cascade](references/bump-cascade.md#vendored-files) rather than by hand. What `check-pins.sh` catches and how it proves itself is in [pinning.md](references/pinning.md#the-guard-is-one-file-not-a-grep-every-repository-re-types), and the same for `check-skill.sh` in [checks.md](references/checks.md#check-skillsh--the-gate-a-skill-repository-needs)

> [!IMPORTANT]
> Copying the secret gate proves nothing. The mechanism travels, the knowledge does not — a copy is worth running only once it has been falsified **in its own repository**: break what it watches, see red, put it back

Asking the same question of a *test suite* — would it notice if the code broke — is the [tests](https://github.com/rokokol/tests-skill) skill's subject, and its `t.sh falsify` lives there

## Tests

```sh
nix develop -c ./check-templates.sh
```

Lints the scripts and every checker template, runs actionlint over every workflow template, runs `check-skill.sh` on this repository's own docs and `check-pins.sh` on its workflows and the workflow templates, then proves each check can fail. actionlint must reject the known-bad workflow in `tests/fixtures/`. The pin guard plants every shape it claims to catch and every pinned spelling it must stay quiet on, itself. The secret gate is exercised end to end in a throwaway repository: clean while scanning only its own source, red on `user/preferences.md` covered by `.gitignore` and admitted with `git add -f`, then red on each planted key shape in turn, naming every finding. And the skill gate plants a defect per check in copies of this repository and requires itself to go red on each. `vendor-sync.sh` is driven end to end against a source repository reached over `file://`: a copy taken with its executable bit, a source commit brought over and recorded in the lock, an unrelated one kept out of it, a vendored directory following deletions and additions, an edit in place named by `check` and refused by `update`, a workflow file taken only as a manual line, and the script updating itself to a longer version while it runs. Every one of those halves was watched failing before it was trusted

## Layout

```
SKILL.md             the rules an agent reads
ci.sh                the harness: status / runs / watch / failed / log / dispatch / rerun
references/          one spec per rule: workflows, pinning, badges, bump-cascade, checks, ops
templates/           copyable workflows, no-secrets.sh, and the travelling check-pins.sh, check-skill.sh and vendor-sync.sh
check-templates.sh   the self-testing template lint
tests/fixtures/      the known-bad inputs the checks must fail on
```
