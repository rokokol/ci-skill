# The build workflow

One workflow, canonically `build.yml`, is the repo's verdict: it runs everything that depends only on the repo. Template: [`templates/github/workflows/build.yml`](../templates/github/workflows/build.yml)

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

`workflow_call` + `ref` is the load-bearing pair, and the one most repos forget. Any automation that wants to verify a branch — the [bump cascade](bump-cascade.md), a drift bot, a release script — calls this workflow against that ref and gets *the real checks*. Copying the check commands into the bot's own workflow creates a second list that drifts, while omitting the `ref` input can make "verify" silently check the default branch instead of the candidate

Every `checkout` step then reads it:

```yaml
- uses: actions/checkout@v7
  with:
    ref: ${{ inputs.ref }}
```

An empty `ref` checks out the triggering commit, so the same lines serve push, PR and call

## Shape

- `permissions: contents: read` at the workflow top. A job that pushes or comments widens its own `permissions:` block — never the whole workflow's
- Fast, separately-named jobs over one megajob: a `lint` status that answers in 40 seconds is worth having next to a 10-minute `build`, and each name becomes a required check you can gate on
- `timeout-minutes` on any job that leaves the machine (network fetches, containers). The default 6 hours is an outage amplifier
- `concurrency: <group>` on any workflow that pushes, so two runs cannot race the same branch
- Steps that must be able to fail loudly do not hide behind `|| true` or `2>/dev/null`; when a distro or platform legitimately cannot run a check, print a visible `SKIP` with `::notice` and exit 0 — green with a mark beats a lying red or a silent pass

## The runner is a platform, not a clean machine

A hosted runner is two layers. The platform — the operating system, its libc and its system userland: BSD `date` and `/bin/bash` 3.2 on macOS, GNU coreutils on Ubuntu — is exactly what a user of that system has, and running a repository's gate there is a direct portability check. Such a job prints the version of every tool it relies on, so an image update leaves evidence in the log. The extras GitHub preinstalls on top — compilers, language runtimes, `jq`, `docker`, whatever the image carries this month — are nobody's machine, and these rules follow for them:

- **A job that exercises the product's install or deploy path supplies that path's dependencies itself** — from the lockfile, a container, a service container — instead of leaning on what the runner happens to carry. A preflight that refuses the runner because a real dependency is absent is *working*; the fix is to give the step the dependency the pinned way, not to soften the check. The honest "does the documented install work on a clean machine" answer comes from a container-based [detector](badges.md), never from the runner
- **A check must not pass because the runner already had something.** Assertions that depend on the runner's incidental contents — a preinstalled compiler, a cached image, a global tool — go green for reasons unrelated to the repo and rot silently when the runner image changes. The line is whether the product declares the thing: a dependency it documents — `jq` for a script that says it needs `jq` — may come from the image when the job prints its version first, so the day an image update changes the answer the log says so; a thing it never declared may not. A job that exercises the install or deploy path is the exception: it supplies even a declared dependency itself, as the first rule says, because proving that path is its whole point

## Anything that can wait for input gets a timeout

`timeout-minutes` belongs on more than network jobs: any step that shells out to an interactive tool can hang forever on a prompt nobody predicted. A provider-selection menu such as `Enter a number (default=1)` rejects `y` and can re-prompt in a loop until the runner kills the job. Answer prompts in the form the specific tool expects — a bare newline takes a menu's default where `y` is invalid — and wrap each such command in `timeout N` so the failure mode is a red step with a readable log instead of an unbounded hang

## Bash in workflow scripts

Workflow `run:` blocks execute under `bash -e`: a standalone `! cmd` skips errexit (actionlint flags SC2251) — write `if cmd; then exit 1; fi`. Quote `$PWD` and friends. Run `actionlint` locally before pushing workflow changes; it embeds shellcheck for exactly these
