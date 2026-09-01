#!/usr/bin/env bash
# The CI harness: everyday GitHub Actions operations as one command each. Wraps gh, so
# auth and repo detection are gh's; every subcommand takes -R owner/repo to aim at
# another repository, defaulting to the one the current directory belongs to.
#
#   ci.sh status              latest run of every workflow — the badge row, in a terminal
#   ci.sh runs [N]            the N most recent runs (default 10)
#   ci.sh watch               follow the runs of the current HEAD until all conclude
#   ci.sh failed [RUN_ID]     the failing steps of a run, then the log lines around the
#                             actual error — not the cleanup noise a raw log tail shows
#   ci.sh dispatch WORKFLOW [REF]
#                             fire a workflow_dispatch and follow it
#   ci.sh rerun [RUN_ID]      rerun the failed jobs of a run (latest failed run if omitted)
set -euo pipefail

usage() { sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

die() {
  printf 'ci.sh: %s\n' "$1" >&2
  exit 1
}

command -v gh >/dev/null || die "needs gh (authenticated: gh auth login)"
command -v jq >/dev/null || die "needs jq"

# -R owner/repo anywhere in the arguments aims every gh call; gh's own default
# (the checkout's origin) applies otherwise
REPO_ARGS=()
args=()
while (($#)); do
  case "$1" in
    -R | --repo)
      REPO_ARGS=(-R "${2:?owner/repo required by $1}")
      shift 2
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done
set -- "${args[@]+"${args[@]}"}"

cmd="${1:-status}"
(($# == 0)) || shift

run_list() { # run_list N [extra gh args...]
  local limit="$1"
  shift
  gh run list "${REPO_ARGS[@]+"${REPO_ARGS[@]}"}" --limit "$limit" \
    --json databaseId,workflowName,status,conclusion,headBranch,event,createdAt "$@"
}

case "$cmd" in
  status)
    # One line per workflow: its most recent run is what the badge shows
    run_list 40 | jq -r '
      group_by(.workflowName)[] | max_by(.createdAt) |
      "\(.workflowName)\t\(if .status != "completed" then .status else .conclusion end)\t\(.headBranch) \(.event)"' |
      sort | column -t -s $'\t'
    ;;

  runs)
    run_list "${1:-10}" | jq -r '.[] |
      "\(.databaseId)\t\(.workflowName)\t\(if .status != "completed" then .status else .conclusion end)\t\(.headBranch) \(.event)"' |
      column -t -s $'\t'
    ;;

  watch)
    # Follow every run of the current HEAD until all conclude; nonzero if any failed.
    # Detectors and gates alike — what you pushed is what gets watched
    sha=$(git rev-parse HEAD 2>/dev/null) || die "watch needs to run inside the checkout"
    while true; do
      state=$(gh run list "${REPO_ARGS[@]+"${REPO_ARGS[@]}"}" --commit "$sha" \
        --json workflowName,status,conclusion)
      [[ "$state" != "[]" ]] || die "no runs for $sha yet — give the push a few seconds"
      pending=$(jq -r '[.[] | select(.status != "completed")] | length' <<<"$state")
      if [[ "$pending" == 0 ]]; then
        jq -r '.[] | "\(.workflowName): \(.conclusion)"' <<<"$state" | sort
        jq -e 'all(.conclusion == "success")' <<<"$state" >/dev/null
        exit
      fi
      printf 'waiting on %s run(s)...\n' "$pending"
      sleep 15
    done
    ;;

  failed)
    # The failing step's own log, not the whole run's tail — a raw tail shows credential
    # cleanup and orphan reaping, never the error
    run_id="${1:-}"
    if [[ -z "$run_id" ]]; then
      run_id=$(run_list 30 | jq -r '[.[] | select(.conclusion == "failure")][0].databaseId // empty')
      [[ -n "$run_id" ]] || die "no failed run among the last 30"
    fi
    gh run view "${REPO_ARGS[@]+"${REPO_ARGS[@]}"}" "$run_id" --json jobs --jq '
      .jobs[] | select(.conclusion == "failure") |
      "== job: \(.name)\n" + ([.steps[] | select(.conclusion == "failure") | "   failed step: \(.name)"] | join("\n"))'
    echo
    # The error itself: the failed-step log, cleanup lines dropped, last screenful kept
    gh run view "${REPO_ARGS[@]+"${REPO_ARGS[@]}"}" "$run_id" --log-failed 2>/dev/null |
      grep -vE 'Removing credentials|Cleaning up orphan|git config --local|git-credentials|^\s*$' |
      tail -40
    ;;

  dispatch)
    wf="${1:?workflow file or name required}"
    ref="${2:-}"
    if [[ -n "$ref" ]]; then
      gh workflow run "${REPO_ARGS[@]+"${REPO_ARGS[@]}"}" "$wf" --ref "$ref"
    else
      gh workflow run "${REPO_ARGS[@]+"${REPO_ARGS[@]}"}" "$wf"
    fi
    echo "dispatched $wf — waiting for the run to appear"
    sleep 5
    run_id=$(gh run list "${REPO_ARGS[@]+"${REPO_ARGS[@]}"}" --workflow "$wf" --limit 1 \
      --json databaseId --jq '.[0].databaseId')
    gh run watch "${REPO_ARGS[@]+"${REPO_ARGS[@]}"}" "$run_id" --exit-status
    ;;

  rerun)
    run_id="${1:-}"
    if [[ -z "$run_id" ]]; then
      run_id=$(run_list 30 | jq -r '[.[] | select(.conclusion == "failure")][0].databaseId // empty')
      [[ -n "$run_id" ]] || die "no failed run among the last 30"
    fi
    gh run rerun "${REPO_ARGS[@]+"${REPO_ARGS[@]}"}" "$run_id" --failed
    gh run watch "${REPO_ARGS[@]+"${REPO_ARGS[@]}"}" "$run_id" --exit-status
    ;;

  -h | --help | help)
    usage
    ;;

  *)
    usage >&2
    exit 1
    ;;
esac
