---
name: ci-standard
description: "What it is — a standard for writing CI that stays green for the right reasons: GitHub Actions conventions (minimal permissions, workflow_call so bots run the real checks, one badge per workflow file), pinned toolchains instead of registry-fate lookups, weekly dependency-bump cascades that land only on green, external-fate jobs kept off pull requests, and falsifiable checks proven able to fail. Use when writing or reviewing any CI workflow, adding badges, setting up dependency auto-updates, deciding what gates a PR, debugging a CI failure that appeared without a code change, or starting CI for a new repo. Triggers: CI, GitHub Actions, workflow, pipeline, badge, cron, dependabot, напиши CI, добавь workflow, бейджи, пайплайн, обнови зависимости в CI."
license: MIT
---

# ci-standard

CI earns its keep only while a green run means something. Everything here serves that one property: a check that cannot fail proves nothing, a job that fails without a code change teaches nothing, and a badge nobody trusts might as well not render. The references carry the reasoning; `templates/` carries copyable GitHub Actions files with `EXAMPLE` markers for the repo-specific parts.

Born from the [huix-standard](https://github.com/rokokol/huix-standard) family rollout, where every rule below was paid for by a real red run; this skill is the provider-general half — nothing here assumes Nix or any language, though the examples lean on GitHub Actions.

## The rules

- **A job is either a gate or a detector — never both.** Checks that depend only on the repo (build, tests, lint) gate pull requests. Checks that depend on someone else's uptime or drift — package mirrors, `:latest` images, live sites — run on push to the default branch, on a weekly cron, and by hand, **never on PRs**: a flaky mirror must not redden someone's change, and the weekly run is the drift detector those checks exist to be. See [references/badges.md](references/badges.md).
- **Every tool a job runs is pinned.** Actions by version (dependabot watches the `uses:` pins), toolchains and linters by the repo's own lockfile — `nix develop`, `npm ci`, `cargo --locked` — never `nix run nixpkgs#tool`, `npx tool@latest`, `pip install tool`. An unpinned lookup is a mirror-fate test: the job changes behavior with zero change in the repo. A guard step greps the workflows for the unpinned patterns and fails on them. See [references/pinning.md](references/pinning.md).
- **The build workflow declares `workflow_call` with a `ref` input**, so automation (dependency bumps, drift bots) verifies branches by running *the real workflow*, not a copy of its commands that drifts apart from it. See [references/workflows.md](references/workflows.md).
- **Dependency updates land themselves, but only on green**: a weekly bump→verify→land cascade — bump onto a dated temp branch, verify by calling the build workflow against it, fast-forward the default branch and delete the branch only when it passed; red leaves the branch standing for a human to look at. See [references/bump-cascade.md](references/bump-cascade.md).
- **One badge per statement.** A GitHub status badge is per workflow file, so anything that deserves its own badge gets a thin wrapper workflow delegating to one reusable job — wrappers differ only in name and input, and the logic lives once. See [references/badges.md](references/badges.md).
- **Every check is proven able to fail.** A new check runs red first — against the pre-fix state or a deliberately broken fixture; checkers ship self-tests against known-bad inputs; assertions on generated text match whole lines, not substrings. A checker that has never been red is a decoration. See [references/checks.md](references/checks.md).
- **One source of truth per list.** File lists for linters, version numbers, tool sets — each lives in exactly one place the others read (the lint list in the build system's own check, the version in a `VERSION` file CI cross-checks against the changelog). Duplicated lists drift; drifted lists lie. See [references/checks.md](references/checks.md).
- **Least privilege, bounded time.** `permissions: contents: read` at the top of every workflow, widened per job only where a job writes; `timeout-minutes` on anything that talks to the network; `concurrency` groups on anything that pushes.

## Layout

```
SKILL.md             this file — the rules
references/          one spec per piece: workflows, pinning, badges, bump-cascade, checks
templates/           copyable GitHub Actions files, EXAMPLE markers for repo specifics
check-templates.sh   actionlint over the templates, self-tested against known-bad fixtures
tests/fixtures/      the known-bad inputs the lint must fail on
```
