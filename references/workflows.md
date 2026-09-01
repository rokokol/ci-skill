# The build workflow

One workflow, canonically `build.yml`, is the repo's verdict: it runs everything that depends only on the repo. Template: [`templates/github/workflows/build.yml`](../templates/github/workflows/build.yml).

## Triggers

```yaml
on:
  push:
    branches: [master]
  pull_request:
  workflow_dispatch:
  workflow_call:
    inputs:
      ref:
        type: string
        required: false
        default: ""
```

`workflow_call` + `ref` is the load-bearing pair, and the one most repos forget. Any automation that wants to verify a branch — the [bump cascade](bump-cascade.md), a drift bot, a release script — calls this workflow against that ref and gets *the real checks*. The alternative, copying the check commands into the bot's own workflow, is a second list that drifts: the family this standard comes from shipped exactly that bug — bots whose "verify" silently checked out the default branch because the `ref` input did not exist.

Every `checkout` step then reads it:

```yaml
- uses: actions/checkout@v7
  with:
    ref: ${{ inputs.ref }}
```

An empty `ref` checks out the triggering commit, so the same lines serve push, PR and call.

## Shape

- `permissions: contents: read` at the workflow top. A job that pushes or comments widens its own `permissions:` block — never the whole workflow's.
- Fast, separately-named jobs over one megajob: a `lint` status that answers in 40 seconds is worth having next to a 10-minute `build`, and each name becomes a required check you can gate on.
- `timeout-minutes` on any job that leaves the machine (network fetches, containers). The default 6 hours is an outage amplifier.
- `concurrency: <group>` on any workflow that pushes, so two runs cannot race the same branch.
- Steps that must be able to fail loudly do not hide behind `|| true` or `2>/dev/null`; when a distro or platform legitimately cannot run a check, print a visible `SKIP` with `::notice` and exit 0 — green with a mark beats a lying red or a silent pass.

## Bash in workflow scripts

Workflow `run:` blocks execute under `bash -e`: a standalone `! cmd` skips errexit (actionlint flags SC2251) — write `if cmd; then exit 1; fi`. Quote `$PWD` and friends. Run `actionlint` locally before pushing workflow changes; it embeds shellcheck for exactly these.
