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
