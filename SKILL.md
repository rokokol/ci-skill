---
name: ci
description: "What it is — a standard for writing CI that stays green for the right reasons: GitHub Actions conventions, pinned toolchains instead of registry-fate lookups, weekly cascades that land dependency bumps and vendored checkers only on green, external-fate jobs kept off pull requests, and falsifiable checks proven able to fail. Use when writing, reviewing or checking any CI workflow, when pushing to a repository that has CI and after the push (ci.sh watch follows the runs to a verdict), when asked whether CI passed or why it went red, when adding badges, setting up dependency auto-updates, deciding what gates a PR, debugging a CI failure that appeared without a code change, or starting CI for a new repo. Triggers: CI, GitHub Actions, workflow, pipeline, badge, cron, dependabot, vendor-sync, vendor.lock, vendored file, push, did CI pass, check CI, напиши CI, проверь CI, посмотри пайплайн, запушь, прошёл ли CI, почему упал CI, добавь workflow, бейджи, обнови зависимости в CI."
license: MIT
---

# ci

CI earns its keep only while a green run means something. Everything here serves that one property: a check that cannot fail proves nothing, a job that fails without a code change teaches nothing, and a badge nobody trusts might as well not render. The references carry the reasoning; `templates/` carries copyable GitHub Actions files with `EXAMPLE` markers for the repo-specific parts

## The rules

- **A job is either a gate or a detector — never both.** Repository-only checks gate pull requests; checks that depend on external uptime or drift run on the default branch, on a schedule and by hand, never on pull requests. See [references/badges.md](references/badges.md)
- **Every tool a job runs is pinned.** Actions use version pins and toolchains come from the repository's lockfile, never a live registry lookup; `templates/check-pins.sh` enforces the distinction. See [references/pinning.md](references/pinning.md)
- **The build workflow declares `workflow_call` with a `ref` input**, so automation (dependency bumps, drift bots) verifies branches by running *the real workflow*, not a copy of its commands that drifts apart from it. See [references/workflows.md](references/workflows.md)
- **Dependency updates land themselves, but only on green.** A scheduled cascade bumps a temporary branch, verifies it through the real build workflow, fast-forwards on green and leaves red for inspection. See [references/bump-cascade.md](references/bump-cascade.md)
- **A file that travels is vendored, and the cascade keeps it current.** The consumer locks a verbatim copy to its source commit and blob, rejects edits in place and advances it only through verification. See [references/bump-cascade.md](references/bump-cascade.md#vendored-files)
- **One badge per statement.** A GitHub status badge is per workflow file, so anything that deserves its own badge gets a thin wrapper workflow delegating to one reusable job — wrappers differ only in name and input, and the logic lives once. See [references/badges.md](references/badges.md)
- **Every check is proven able to fail.** A new check runs red first against the pre-fix state or a deliberately broken fixture; checkers exercise known-bad inputs; assertions on generated text match whole lines, not substrings. A checker that has never been red is a decoration. Reusable checkers live in `templates/`; each either marks the knowledge a consumer must supply or proves its generic mechanism on every run. See [references/checks.md](references/checks.md)
- **One source of truth per list.** File lists for linters, tool sets and version numbers each live in exactly one place that every check reads or verifies against. Duplicated lists drift; drifted lists lie. See [references/checks.md](references/checks.md)
- **Least privilege, bounded time.** `permissions: contents: read` at the top of every workflow, widened per job only where a job writes; `timeout-minutes` on anything that talks to the network; `concurrency` groups on anything that pushes
- **Tracked files obey `.gitignore`.** When a repository has ignore rules, `no-secrets.sh` rejects any tracked path matched by them; `git add -f` must not silently turn a local artifact into repository content. See [references/checks.md](references/checks.md)
- **A push is not done until its runs conclude.** Run the workflow's gate locally, push, then use `ci.sh watch` and report its verdict; rerun only a failure with a named external cause. See [references/ops.md](references/ops.md)

## The harness

[`ci.sh`](ci.sh) beside this file is the operational half — one command per everyday operation, from the badge row in a terminal to the whole log of a single job. Use it instead of hand-rolling `gh run` invocations; `ci.sh help` lists every subcommand, and [references/ops.md](references/ops.md) is the push ritual they serve and the raw `gh --json/--jq` recipes they are built from
