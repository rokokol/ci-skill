# The bump cascade — dependencies land themselves, on green only

Lockfiles age on their own; nothing in normal development moves them. The cascade is one weekly workflow — template: [`templates/github/workflows/bump-cascade.yml`](../templates/github/workflows/bump-cascade.yml):

1. **bump** — run the ecosystem's update command (`nix flake update`, `npm update`, `cargo update`, `pre-commit autoupdate`…). If the lockfile did not change, stop quietly. Otherwise commit it to a dated temp branch (`bump/2026-08-31`) and push
2. **verify** — call the repo's own build workflow against that branch:

   ```yaml
   verify:
     needs: bump
     if: needs.bump.outputs.moved == '1'
     uses: ./.github/workflows/build.yml
     with:
       ref: ${{ needs.bump.outputs.branch }}
   ```

   The whole point of the temp branch is that a reusable workflow checks out a *ref*, so the bump has to exist somewhere before the real checks can see it. This is also why [build.yml declares `workflow_call` + `ref`](workflows.md) — verify runs the real checks, never a copy of their commands
3. **land** — fast-forward the default branch onto the verified tree and delete the temp branch. **Red skips this**: the branch stays, with the bump on it, so a human can look at what the new dependency broke and resolve it deliberately (often as one commit combining the bump with the change it demands — see [pinning.md](pinning.md))

Guard rails: `concurrency: <one group>` on the workflow (two runs would push the same branch from different bases), `permissions: contents: write` only on the jobs that push, full-history checkout for the push (`fetch-depth: 0` — pushing from a shallow clone is refused), commits under the `github-actions[bot]` identity

## When the bot lands under you

Work on the repo during the bump window and the cascade will land a lockfile under your feet — your push comes back rejected. The canon: rebase onto the updated default branch, **re-run the checks on the fresh lock** (the bump can bring a formatter with a changed opinion or a toolchain with changed behavior — the very thing verify caught on its own branch), then push. Never force-push over the bot's commit: it landed on green and is as much the default branch as your work is

**A checkout being behind is not the repository being behind, and only a `fetch` tells them apart.** `vendor-sync.sh check` holds each copy to the blob its own lock line records, not to its source, so a checkout that missed the last two cascade runs passes it and reads as current; and a lock line names the revision the last `update` took, never the one on the source's default branch. Measured: a sweep across the family read three repositories as having missed a whole round, on the evidence of their local logs and locks — what they had missed was a `fetch`, the cascade having landed there days earlier under the `github-actions[bot]` identity. So a claim that a consumer is stale is made after fetching it, and a not-fast-forward on the push is the cheapest place to be told otherwise

The same bump→verify→land (or bump→verify→PR, where review is wanted) shape serves any "the world moved" bot: re-rendering generated assets against an upstream's HEAD, refreshing recorded fixtures from a live site, re-measuring data a repo mirrors. Verify is always the same call; only the bump command changes. In this skill "the cascade" always means this bump→verify→land shape, for a lockfile or for a vendored file; it is not dependabot, not a reusable workflow pinned at `@v1`, and not a composite action

## Vendored files

A file another repository owns — a checker, a harness, a set of markers — is kept in the consuming repository as a verbatim copy, and the same bump→verify→land shape keeps it current. [`templates/vendor-sync.sh`](../templates/vendor-sync.sh) is the tool and [`templates/github/workflows/vendor-sync.yml`](../templates/github/workflows/vendor-sync.yml) the weekly run. This section is the one place the mechanism is described: the skills that hand out files, the header of every file that travels and the header of every lock point here

- **Why a copy at all.** A gate runs the same command locally and in CI, and a hosted runner has no skills directory to call a checker from. A copy in the repository runs wherever the gate runs, with no network and no toolchain beyond the gate's own; the lock and cascade keep that copy from drifting
- **The lock is the record.** `.github/vendor.lock` holds one line per copy: `LOCAL OWNER/REPO PATH COMMIT BLOB`, with `manual` at the end for the case below. `COMMIT` is the source commit the content was taken at, so `git log COMMIT..HEAD -- PATH` in the source shows exactly what a stale copy lacks. It moves only when the content does, so a source's unrelated commits never reach the lock. `BLOB` is what the copy must still hash to: a file's git blob, or for a directory — a `PATH` ending in `/`, kept whole — the blob of its sorted listing
- **A copy is never edited in place.** `vendor-sync.sh check` is offline and belongs in the gate: a copy that no longer hashes to its `BLOB` fails the gate by name, and `update` refuses to run over it. The change goes to the source, and the cascade brings it back to every consumer at once
- **A copy and its line land in one commit.** `update` takes every copy whose source has moved, not only the one being aimed at, and prints a `took` line for each. Staging the lock with only some of those copies leaves it recording a blob the committed file is not, and `check` fails the next run on the copy left behind. Stage every file `update` named together with `.github/vendor.lock`
- **A copy changes its source through a new line, never an edited one.** `add` refuses a file the lock already lists, and `update` only follows the source a line records. Delete the copy's line from `.github/vendor.lock` by hand, since the lock is a record rather than a vendored file, then `add` the same local path from the new source. The old source removes its file only after every consumer's lock has stopped naming it: a consumer still pointing there fails its weekly `update` on the missing path
- **No version is needed.** `COMMIT` identifies the exact source revision a consumer has, with nothing else to bump and no tag to move
- **Workflow files are manual.** The `GITHUB_TOKEN` a workflow runs with cannot push a change under `.github/workflows/`, and no `permissions:` block lifts that. Such a copy is taken with `--manual`: `check` guards it like any other, the weekly `update` skips it, and a person refreshes it with `vendor-sync.sh update --manual`
- **A copy has to pass its strictest consumer.** A consumer cannot edit a vendored file, so a linter it runs and the source does not is satisfied at the source, where every consumer gets the change; for example, a workflow vendored into a repository running `yamllint --strict` needs its `---` document start at the source
- **A copy that falsifies itself does so once per run, and on every run.** Its self-test proves the copy's bytes under this run's bash and tools, so a second call in the same run proves nothing new: every call after the first sets the variable the copy's help names for that (`CHECK_SH_NESTED=1`, `CHECK_SKILL_NESTED=1`), and so does a copy of the gate run to watch a planted defect go red, as long as the plant lands outside what the self-test reads. The first call keeps it on every push, because what it catches is a copy that stopped finding defects and stayed green, and its inputs move without an event a consumer could wait for: a self-test that plants into a copy of the consumer's repository reads that repository, a consumer with no lock runs on the runner image's tools, and a skip keyed on a hash of the copy, the lock and the call would be a second record of what the locks already hold. A self-test too slow for every push is made faster at the source, where every consumer gets the change
- **The tool vendors itself.** `vendor-sync.sh` is one of the copies its own lock lists, so the cascade updates it like the rest. It replaces a copy rather than rewriting it, because bash reads a script while running it and would carry on into the new text of a script rewritten under it

### Taking a file

```sh
cp <a checkout of ci-skill>/templates/vendor-sync.sh .   # the only copy made by hand
./vendor-sync.sh add vendor-sync.sh rokokol/ci-skill templates/vendor-sync.sh
./vendor-sync.sh add check-pins.sh rokokol/ci-skill templates/check-pins.sh
./vendor-sync.sh check                                   # and the same line in the gate
```

The first `add` replaces the hand copy with the tracked one, so even the bootstrap ends up under the lock. The cascade's own workflow is taken the same way, as a manual line: `./vendor-sync.sh add --manual .github/workflows/vendor-sync.yml rokokol/ci-skill templates/github/workflows/vendor-sync.yml`. It calls `.github/workflows/build.yml`, and `uses:` takes only a literal, so a repository whose build workflow goes by another name renames it to `build.yml`, and the badge link with it, rather than keeping a hand-edited copy. For the same reason `vendor-sync.sh` sits at the repository root, where the workflow calls it. That build workflow declares `workflow_call` with a `ref` input, as [workflows.md](workflows.md) requires anyway. A source is fetched over https with no credentials, so it has to be public. The cascade's cron runs ahead of the dependency bump's, so a week's fixes to the shared checkers are in place when the bump is verified

GitHub lists a workflow and runs its triggers only after a push to the default branch that changes the file; a change reverted within the same push, or a push to another branch, registers nothing. A manual line whose workflow never appears under Actions is registered by a real change on the default branch: edit the file, write its new blob into the lock in the same commit so `check` stays green, push, then revert both in a second push
