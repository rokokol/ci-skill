# Operating CI — the harness and the raw gh recipes

[`ci.sh`](../ci.sh) beside SKILL.md wraps the everyday operations; run it from a checkout, or aim it with `-R owner/repo`. `ci.sh help` lists every subcommand, what it answers and what it defaults to; this page carries what a help has no room for — the push ritual the subcommands serve, why `failed` filters the log, how to wait without polling, the raw `gh --json/--jq` recipes they are built from, and what to suspect when a local run and CI disagree

## The push ritual

A push to a repository that has CI is a claim — "this is green" — and the claim is settled by the runs, not by the push returning. In order:

1. **Run the gate locally first**, with the command the workflow runs, under the pinned toolchain the workflow uses (`nix develop -c ./check.sh`, `npm ci && npm test`, whatever `build.yml` says). Anything that goes red here would have gone red there twenty minutes later; a push that skips this step is a slower way to run the check
2. **Push, then `ci.sh watch`.** It follows every run of the pushed HEAD — gates and detectors alike — and exits nonzero if any failed. Do not go on to the next task while it waits, and do not report "pushed" as if it were "green"
3. **On red, `ci.sh failed`** names the failing steps and shows the log around the real error. Fix, run the gate locally again, push again. The one exception is a detector that reddened on an external cause — a mirror down, a `:latest` image that moved — which is exactly what the [gate/detector split](badges.md) is for: name the cause, and only then `ci.sh rerun`
4. **Report the verdict**: which workflows ran, what each concluded, and the fix if there was one. "Pushed" is not a result

The first step is also why the gate and the workflow must run *the same command*: two lists of checks drift, and the local one is always the one that drifts toward green

## Why `failed` filters the log

`gh run view --log-failed` ends every job with the runner's teardown — credential-config unsets, orphan-process reaping — dozens of lines that bury the error, and on a multi-job run the tail you look at is often the *wrong job's* teardown. The reliable route, which the harness automates:

```sh
gh run view <id> --json jobs --jq '
  .jobs[] | select(.conclusion == "failure") |
  {job: .name, steps: [.steps[] | select(.conclusion == "failure") | .name]}'
```

— first learn *which step* failed, then read that job's log with the teardown noise dropped. When even that shows only "builder failed with exit code 1" (a nested build system), reproduce locally — for nix, `nix log <drv>` has the builder's own lines

## Watching without polling spam

One loop, one verdict — never a stream of list calls pasted by hand:

```sh
sha=$(git rev-parse HEAD)
while true; do
  s=$(gh run list --commit "$sha" --json workflowName,status,conclusion)
  jq -e 'all(.status == "completed")' <<<"$s" >/dev/null && break
  sleep 15
done
jq -r '.[] | "\(.workflowName): \(.conclusion)"' <<<"$s"
```

`--commit` scopes to what was just pushed, so a cron run finishing in parallel does not sneak into the verdict

## Recipes worth keeping verbatim

```sh
# the newest run per workflow (what each badge currently shows)
gh run list --limit 40 --json workflowName,status,conclusion,createdAt |
  jq -r 'group_by(.workflowName)[] | max_by(.createdAt) | "\(.workflowName): \(.conclusion // .status)"'

# did the weekly bump land? — the cascade's last verdict
gh run list --workflow bump-cascade --limit 1 --json conclusion --jq '.[0].conclusion'

# every failed run across a set of repos, one gh call each
for r in repo-a repo-b; do gh run list -R owner/$r --limit 5 \
  --json workflowName,conclusion --jq '.[] | select(.conclusion=="failure") | "'$r': \(.workflowName)"'; done
```

Worth doing every time: always take `--json ... --jq` over scraping the table output (the table reorders and truncates), and read a run id once with `runs` rather than re-listing per command

## When local and CI disagree, suspect the observer

A check that fails on your machine and passes on the runner (or the reverse) is not automatically a flake — before touching the check, account for what differs about *where you are watching from*. The usual suspects are your network: a VPN or corporate proxy that a container's own bridge quietly bypasses, a CDN that geo-blocks your exit but not the runner's, a local mirror or DNS that resolves differently. Reproduce the network the check actually needs (`--network host` for a container that must share your routing, or the plain interface when it must not) before concluding the check is wrong. CI runners, boring and unproxied, are the tiebreaker: when they disagree with you, the anomaly is usually on your side
