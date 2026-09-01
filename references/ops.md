# Operating CI — the harness and the raw gh recipes

[`ci.sh`](../ci.sh) beside SKILL.md wraps the everyday operations; run it from a checkout, or aim it with `-R owner/repo`. What it does and why each subcommand exists:

| Subcommand | What it answers |
|---|---|
| `ci.sh status` | the badge row in a terminal: every workflow's latest run, one line each |
| `ci.sh runs [N]` | recent runs with ids, for picking a target |
| `ci.sh watch` | block until every run of the current HEAD concludes; nonzero if any failed — the after-push command |
| `ci.sh failed [ID]` | the failing steps, then the log around the actual error (latest failed run if no id) |
| `ci.sh dispatch WF [REF]` | fire a `workflow_dispatch` and follow it to a verdict |
| `ci.sh rerun [ID]` | rerun a run's failed jobs and follow |

## Why `failed` filters the log

`gh run view --log-failed` ends every job with the runner's teardown — credential-config unsets, orphan-process reaping — dozens of lines that bury the error, and on a multi-job run the tail you look at is often the *wrong job's* teardown. The reliable route, which the harness automates:

```sh
gh run view <id> --json jobs --jq '
  .jobs[] | select(.conclusion == "failure") |
  {job: .name, steps: [.steps[] | select(.conclusion == "failure") | .name]}'
```

— first learn *which step* failed, then read that job's log with the teardown noise dropped. When even that shows only "builder failed with exit code 1" (a nested build system), reproduce locally — for nix, `nix log <drv>` has the builder's own lines.

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

`--commit` scopes to what was just pushed, so a cron run finishing in parallel does not sneak into the verdict.

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

Two habits: always take `--json ... --jq` over scraping the table output (the table reorders and truncates), and read a run id once with `runs` rather than re-listing per command.
