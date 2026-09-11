#!/usr/bin/env bash
# The CI harness: everyday GitHub Actions operations as one command each. Wraps gh, so
# auth and repo detection are gh's; every subcommand takes -R, --repo owner/repo to aim
# at another repository, defaulting to the one the current directory belongs to.
#
#   ci.sh status              latest run of every workflow — the badge row, in a terminal
#   ci.sh runs [N]            the N most recent runs (default 10)
#   ci.sh watch               follow the runs of the current HEAD until all conclude
#   ci.sh failed [RUN_ID]     the steps of a run that went wrong — failed, cancelled or
#                             timed out alike — then the log lines around the actual
#                             error, not the cleanup noise a raw log tail shows (the
#                             newest of the last 30 runs that went wrong if omitted)
#   ci.sh log [RUN_ID] [JOB]  the whole log of one job, whatever it concluded: the first
#                             green run of a new job is the one worth reading (the
#                             latest run if omitted; JOB only when the run has several)
#   ci.sh dispatch WORKFLOW [REF]
#                             fire a workflow_dispatch and follow it
#   ci.sh rerun [RUN_ID]      rerun the failed jobs of a run (latest failed run if omitted)
#
# Exit 0 done, 2 on a usage error or without gh and jq; watch, dispatch and rerun pass
# the run's own conclusion through, nonzero when it failed, as gh reports it.
set -euo pipefail

# The whole header, however long it grows: up to the first line that is not a comment
usage() { sed -n '2,/^[^#]/p' "${BASH_SOURCE[0]}" | sed '$d; s/^# \{0,1\}//'; }

die() { # the request itself is wrong, or cannot be served as asked
  printf 'ci.sh: %s\n' "$1" >&2
  exit 2
}

# -R owner/repo anywhere in the arguments aims every gh call; gh's own default
# (the checkout's origin) applies otherwise
REPO_ARGS=()
args=()
while (($#)); do
  case "$1" in
    -R | --repo)
      # Not ${2:?}: that exits 1 with bash's own message, and a usage error is 2
      (($# >= 2)) || die "$1 needs owner/repo"
      REPO_ARGS=(-R "$2")
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

# The help needs neither tool, and a machine without them still gets to read it
case "$cmd" in
  -h | --help | help) ;;
  *)
    command -v gh >/dev/null || die "needs gh (authenticated: gh auth login)"
    command -v jq >/dev/null || die "needs jq"
    ;;
esac

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
    # cleanup and orphan reaping, never the error.
    #
    # "Went wrong" is anything that concluded and was not a success: a job killed by
    # `timeout-minutes` concludes `cancelled`, one whose runner never came up
    # `startup_failure`, and `timed_out` exists as well. Selecting on `failure` alone left
    # this blind to exactly the run worth reading — a gate cancelled at its job timeout
    # printed nothing here, and exited nonzero while printing it, because the empty log
    # went through a `grep -v` under pipefail.
    run_id="${1:-}"
    if [[ -z "$run_id" ]]; then
      run_id=$(run_list 30 | jq -r '[.[] | select(.conclusion // "" | . != "" and . != "success" and . != "skipped")][0].databaseId // empty')
      [[ -n "$run_id" ]] || die "no run among the last 30 went wrong"
    fi
    jobs_json=$(gh run view "${REPO_ARGS[@]+"${REPO_ARGS[@]}"}" "$run_id" --json jobs)
    bad=$(jq -c '[.jobs[] | select(.conclusion // "" | . != "" and . != "success" and . != "skipped")]' <<<"$jobs_json")
    if [[ "$(jq -r 'length' <<<"$bad")" == 0 ]]; then
      # Said out loud, because silence here is indistinguishable from a reader that cannot
      # see — which is the bug this subcommand had
      printf 'run %s: nothing went wrong — every job concluded success\n' "$run_id"
      exit 0
    fi
    jq -r '.[] |
      "== job: \(.name) (\(.conclusion))\n" +
      ([.steps[] | select(.conclusion // "" | . != "" and . != "success" and . != "skipped") |
        "   \(.conclusion) step: \(.name)"] | join("\n"))' <<<"$bad"
    echo
    # The error itself. --log-failed has nothing to give for a job that was cancelled
    # rather than failed, so fall back to the whole log of each job that went wrong
    raw=$(gh run view "${REPO_ARGS[@]+"${REPO_ARGS[@]}"}" "$run_id" --log-failed 2>/dev/null || :)
    if [[ -z "${raw//[[:space:]]/}" ]]; then
      while IFS= read -r job_id; do
        [[ -n "$job_id" ]] || continue
        raw+=$(gh run view "${REPO_ARGS[@]+"${REPO_ARGS[@]}"}" "$run_id" --log --job "$job_id" 2>/dev/null || :)$'\n'
      done < <(jq -r '.[].databaseId' <<<"$bad")
    fi
    printf '%s\n' "$raw" |
      grep -vE 'Removing credentials|Cleaning up orphan|git config --local|git-credentials|^\s*$' |
      tail -40 || :
    ;;

  log)
    # The whole log of one job, whatever it concluded. `failed` cannot give you this: a job
    # that passed has no failing step, and the first green run of a job that has never run
    # before is exactly the one worth reading rather than trusting
    run_id="${1:-}"
    job=""
    (($# < 2)) || job="$2"
    if [[ -z "$run_id" ]]; then
      run_id=$(run_list 1 | jq -r '.[0].databaseId // empty')
      [[ -n "$run_id" ]] || die "no run to read"
    fi
    jobs_json=$(gh run view "${REPO_ARGS[@]+"${REPO_ARGS[@]}"}" "$run_id" --json jobs)
    if [[ -z "$job" ]]; then
      names=$(jq -r '.jobs[].name' <<<"$jobs_json")
      [[ "$(grep -c . <<<"$names")" == 1 ]] ||
        die "run $run_id has more than one job — name one of: $(tr '\n' ' ' <<<"$names")"
      job="$names"
    fi
    job_id=$(jq -r --arg n "$job" '[.jobs[] | select(.name == $n) | .databaseId][0] // empty' <<<"$jobs_json")
    [[ -n "$job_id" ]] ||
      die "run $run_id has no job called '$job' — it has: $(jq -r '[.jobs[].name] | join(", ")' <<<"$jobs_json")"
    gh run view "${REPO_ARGS[@]+"${REPO_ARGS[@]}"}" "$run_id" --log --job "$job_id"
    ;;

  dispatch)
    # Not ${1:?}: that exits 1 with bash's own message, and a usage error is 2
    (($# >= 1)) || die "dispatch needs a workflow file or name"
    wf="$1"
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
    printf 'ci.sh: no such subcommand: %s\n\n' "$cmd" >&2
    usage >&2
    exit 2
    ;;
esac
