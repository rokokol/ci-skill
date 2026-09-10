# Badges, and what may gate a pull request

## Gate vs detector

Sort every check by what its failure would mean:

- **Gate** — the failure indicts the change: build, unit tests, lint, type check. Runs on `pull_request` and blocks merging.
- **Detector** — the failure indicts the world: jobs against `:latest` container images, package mirrors, live websites, third-party APIs. Runs on push to the default branch, weekly cron, and `workflow_dispatch` — **never on `pull_request`**. A Debian mirror having an afternoon must not redden someone's rename; and since the weekly run re-pulls whatever drifted upstream, it *is* the early-warning system those checks exist to be. Red on a detector is a signal to investigate, not noise to retry.

A detector that becomes reliable enough to gate is a judgment call to revisit — but the default is separation, because a gate people learn to re-run on flake stops gating anything.

A job on a runner of a platform the product supports, run with that platform's own tools, is a gate: what turns it red is nearly always the change itself — a GNU-only flag, a construct bash 3.2 rejects — and the rare red that an image update causes names itself in the tool versions such a job prints before it runs. What counts as the platform, and what the image merely happens to carry, is in [workflows.md](workflows.md#the-runner-is-a-platform-not-a-clean-machine)

## One badge per statement

A GitHub status badge is per **workflow file** (`actions/workflows/<file>/badge.svg`), not per job. So each statement the README should make — "installs on Debian", "installs on Fedora", "builds" — needs its own workflow file. Duplicating the job four times reintroduces drift, so the logic lives once in a reusable workflow and each badge-bearing file is a thin wrapper:

```yaml
# distro-debian.yml — differs from its siblings only in name and input
name: debian
on:
  push:
    branches: [master]
  schedule:
    - cron: "0 5 * * 1"
  workflow_dispatch:
permissions:
  contents: read
jobs:
  test:
    uses: ./.github/workflows/distro.yml
    with:
      distro: debian
```

The reusable half declares `workflow_call` with the input and carries the whole job. Badge row in the README, in a fixed order, each badge linking to its workflow page:

```markdown
[![build](https://github.com/OWNER/REPO/actions/workflows/build.yml/badge.svg)](https://github.com/OWNER/REPO/actions/workflows/build.yml)
[![debian](https://github.com/OWNER/REPO/actions/workflows/distro-debian.yml/badge.svg)](https://github.com/OWNER/REPO/actions/workflows/distro-debian.yml)
```

A detector's badge then reads honestly: the verdict of the last push or weekly run against the current world — exactly what a visitor deciding whether the thing works today wants to know.

## Cron choreography

When several repos or several workflows feed each other (a data repo → its consumers → an aggregator), stagger their crons so a week's drift flows through in one morning instead of arriving a week late at each hop. Put the wrapper detectors *before* the dependency-bump wave, so the drift report is about the world, not about a bump that landed an hour earlier.
