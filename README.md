<div align="center">

# ci-standard

**CI that stays green for the right reasons (￣ー￣)ゞ**

![GitHub Actions](https://img.shields.io/badge/GitHub-Actions-2088FF?logo=githubactions&logoColor=white)
![Nix flake](https://img.shields.io/badge/Nix-flake-7EBAE4?logo=nixos&logoColor=white)
[![license](https://img.shields.io/badge/code-MIT-3DA639)](LICENSE)
[![ci](https://github.com/rokokol/ci-standard/actions/workflows/ci.yml/badge.svg)](https://github.com/rokokol/ci-standard/actions/workflows/ci.yml)

</div>

A [Claude Code skill](https://docs.anthropic.com/en/docs/claude-code) that standardizes how CI is written: what may gate a pull request and what runs as a weekly drift detector, why every tool a job runs comes from the repo's lockfile, how dependency bumps land themselves on green, how a README gets one honest badge per statement, and why a check that has never been red proves nothing.

Extracted from [huix-standard](https://github.com/rokokol/huix-standard), where every rule was paid for by a real red run; this is the provider-general half — nothing here assumes Nix or any language, though the templates are GitHub Actions.

## Contents

- [Use as a skill](#use-as-a-skill)
- [What the standard says](#what-the-standard-says)
- [Tests](#tests)
- [Layout](#layout)

## Use as a skill

```sh
git clone https://github.com/rokokol/ci-standard ~/Projects/ci-standard
ln -s ~/Projects/ci-standard ~/.claude/skills/ci-standard
```

Then ask Claude Code to write or review CI — [SKILL.md](SKILL.md) carries the rules, `references/` the reasoning, `templates/` the copyable GitHub Actions files with `EXAMPLE` markers for the repo-specific parts.

## What the standard says

- [Gate or detector, never both](references/badges.md): repo-only checks gate PRs; world-facing checks run on push + weekly cron and get their own badge each — one workflow file per badge, one reusable job behind the thin wrappers.
- [Everything pinned](references/pinning.md): actions by version under dependabot, tools from the repo's own lockfile, a guard step that fails the build on unpinned registry lookups — and a formatter's opinion change lands in the same commit as its lockfile bump.
- [The build workflow is callable](references/workflows.md): `workflow_call` + `ref`, so bots verify branches with the real checks instead of a drifting copy.
- [Bumps land themselves on green](references/bump-cascade.md): weekly bump→verify→land, red leaves the dated branch standing for a human.
- [Checks are falsifiable](references/checks.md): red first, self-tested checkers, whole-line assertions, one source of truth per list, and a VERSION↔CHANGELOG gate.
- [An operational harness](references/ops.md): `ci.sh` for status, watch-until-verdict, failed-step logs without the runner's teardown noise, dispatch-and-follow and rerun.

## Tests

```sh
nix develop -c ./check-templates.sh
./ci.sh status            # and the harness itself: the badge row in a terminal
```

Runs actionlint over every template, then feeds it the known-bad fixture from `tests/fixtures/` — the run fails unless the fixture does.

## Layout

```
SKILL.md             the rules
references/          workflows, pinning, badges, bump-cascade, checks
templates/           copyable GitHub Actions files, EXAMPLE markers for repo specifics
check-templates.sh   the self-testing template lint
tests/fixtures/      known-bad inputs the lint must fail on
```
