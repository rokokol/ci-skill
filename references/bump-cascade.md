# The bump cascade — dependencies land themselves, on green only

Lockfiles age on their own; nothing in normal development moves them. The cascade is one weekly workflow with three jobs — template: [`templates/github/workflows/bump-cascade.yml`](../templates/github/workflows/bump-cascade.yml):

1. **bump** — run the ecosystem's update command (`nix flake update`, `npm update`, `cargo update`, `pre-commit autoupdate`…). If the lockfile did not change, stop quietly. Otherwise commit it to a dated temp branch (`bump/2026-08-31`) and push.
2. **verify** — call the repo's own build workflow against that branch:

   ```yaml
   verify:
     needs: bump
     if: needs.bump.outputs.moved == '1'
     uses: ./.github/workflows/build.yml
     with:
       ref: ${{ needs.bump.outputs.branch }}
   ```

   The whole point of the temp branch is that a reusable workflow checks out a *ref*, so the bump has to exist somewhere before the real checks can see it. This is also why [build.yml declares `workflow_call` + `ref`](workflows.md) — verify runs the real checks, never a copy of their commands.
3. **land** — fast-forward the default branch onto the verified tree and delete the temp branch. **Red skips this**: the branch stays, with the bump on it, so a human can look at what the new dependency broke and resolve it deliberately (often as one commit combining the bump with the change it demands — see [pinning.md](pinning.md)).

Guard rails: `concurrency: <one group>` on the workflow (two runs would push the same branch from different bases), `permissions: contents: write` only on the jobs that push, full-history checkout for the push (`fetch-depth: 0` — pushing from a shallow clone is refused), commits under the `github-actions[bot]` identity.

## When the bot lands under you

Work on the repo during the bump window and the cascade will land a lockfile under your feet — your push comes back rejected. The canon: rebase onto the updated default branch, **re-run the checks on the fresh lock** (the bump can bring a formatter with a changed opinion or a toolchain with changed behavior — the very thing verify caught on its own branch), then push. Never force-push over the bot's commit: it landed on green and is as much the default branch as your work is.

The same bump→verify→land (or bump→verify→PR, where review is wanted) shape serves any "the world moved" bot: re-rendering generated assets against an upstream's HEAD, refreshing recorded fixtures from a live site, re-measuring data a repo mirrors. Verify is always the same call; only the bump command changes.

## Vendored files

A file another repository owns — a checker, a harness, a set of markers — is kept in the consuming repository as a verbatim copy, and the same bump→verify→land shape keeps it current. [`templates/vendor-sync.sh`](../templates/vendor-sync.sh) is the tool and [`templates/github/workflows/vendor-sync.yml`](../templates/github/workflows/vendor-sync.yml) the weekly run. This section is the one place the mechanism is described: the skills that hand out files, the header of every file that travels and the header of every lock point here

- **Why a copy at all.** A gate runs the same command locally and in CI, and a hosted runner has no skills directory to call a checker from. A copy in the repository runs wherever the gate runs, with no network and no toolchain beyond the gate's own. What was wrong with the copies was only that they were kept by hand, and drifted
- **The lock is the record.** `.github/vendor.lock` holds one line per copy: `LOCAL OWNER/REPO PATH COMMIT BLOB`, with `manual` at the end for the case below. `COMMIT` is the source commit the content was taken at, so `git log COMMIT..HEAD -- PATH` in the source shows exactly what a stale copy lacks. It moves only when the content does, so a source's unrelated commits never reach the lock. `BLOB` is what the copy must still hash to: a file's git blob, or for a directory — a `PATH` ending in `/`, kept whole — the blob of its sorted listing
- **A copy is never edited in place.** `vendor-sync.sh check` is offline and belongs in the gate: a copy that no longer hashes to its `BLOB` fails the gate by name, and `update` refuses to run over it. The change goes to the source, and the cascade brings it back to every consumer at once
- **No version is needed.** A skill that hands out files still has none, as the [versioning](https://github.com/rokokol/versioning-skill) skill says: what a consumer has is pinned by `COMMIT`, which answers "which one do you have" more exactly than a number would, with nothing to bump and no tag to move
- **Workflow files are manual.** The `GITHUB_TOKEN` a workflow runs with cannot push a change under `.github/workflows/`, and no `permissions:` block lifts that. Such a copy is taken with `--manual`: `check` guards it like any other, the weekly `update` skips it, and a person refreshes it with `vendor-sync.sh update --manual`
- **The tool vendors itself.** `vendor-sync.sh` is one of the copies its own lock lists, so the cascade updates it like the rest. It replaces a copy rather than rewriting it, because bash reads a script while running it and would carry on into the new text of a script rewritten under it

### Taking a file

```sh
cp <a checkout of ci-skill>/templates/vendor-sync.sh .   # the only copy made by hand
./vendor-sync.sh add vendor-sync.sh rokokol/ci-skill templates/vendor-sync.sh
./vendor-sync.sh add check-pins.sh rokokol/ci-skill templates/check-pins.sh
./vendor-sync.sh check                                   # and the same line in the gate
```

The first `add` replaces the hand copy with the tracked one, so even the bootstrap ends up under the lock. The cascade's own workflow is taken the same way, as a manual line: `./vendor-sync.sh add --manual .github/workflows/vendor-sync.yml rokokol/ci-skill templates/github/workflows/vendor-sync.yml`. It calls `.github/workflows/build.yml`, and `uses:` takes only a literal, so a repository whose build workflow goes by another name renames it to `build.yml` rather than keeping a hand-edited copy of this one: eleven such copies, one line apart, were the first thing this cascade was rolled out with, and exactly the drift it exists to end. That workflow declares `workflow_call` with a `ref` input, as [workflows.md](workflows.md) requires anyway. Its cron sits at 04:00 on Monday, ahead of any dependency bump, so a week's fixes to the shared checkers are in place when the bump is verified
