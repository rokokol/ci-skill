# Pinning — a job's behavior changes only when the repo changes

An unpinned tool lookup is a mirror-fate test: `nix run nixpkgs#shfmt`, `npx prettier@latest`, `pip install ruff`, `go install tool@latest` all resolve to whatever the registry serves that morning, and the job goes red — or worse, green against different behavior — for no change in the repo. Real cases that paid for this rule: a formatter minor release that reversed its own spacing opinion (shfmt 3.14 vs 3.13 on `((!x))`), a Go tool whose `@latest` was a 2018 tag resolving fresh dependencies too new for the distro's compiler, and a network daemon whose new version renamed the nftables chains a routing test asserted.

## The rules

- **Actions by version, watched.** `uses: actions/checkout@v7` — a major tag, not `@master` — with dependabot's `github-actions` ecosystem on weekly, so the pin moves by PR, not by surprise.
- **Toolchains and linters from the repo's own lockfile.** Whatever the ecosystem's pinned entrypoint is — `nix develop -c <tool>` (the dev shell is the pinned toolbox), `npm ci` + `npx --no-install`, `cargo run --locked`, a `uv`/`poetry` lock — the tool version is decided by a committed file, and updating it is a diff someone reviews (or the [bump cascade](bump-cascade.md) lands on green).
- **A guard enforces it** — [`templates/check-pins.sh`](../templates/check-pins.sh), copied verbatim into the repository and run by the build workflow or by the repo's own gate, greps the workflows for the unpinned shapes and fails on a match, so the rule survives the next contributor:

```yaml
- name: CI tools come from the lock, not the registry
  run: ./check-pins.sh
```

Keep the step's name stable so it reads as policy, not as a stray grep.

### The guard is one file, not a grep every repository re-types

The first form of this rule was an inline `grep -rEn '...' .github/workflows` in the build workflow, and it drifted the way every re-typed list drifts: within a week the repository the rule came from carried only the `nix run` alternative, two others carried the full pattern, this reference carried a third spelling, and a dozen more repositories each had their own copy of one of them. Widening the pattern meant editing all of them by hand, so it was not widened. `check-pins.sh` is the one source: it travels by copying, and a copy is proven in place — on every run it plants one line per shape it claims to catch, each alone in a throwaway workflow, and requires a finding that quotes that line; then every pinned spelling together (`nix develop -c`, `npx --no-install`, `cargo install --locked`, an action at a version tag, a line marked `# check-pins: allow`, a comment) which must stay green; and a directory with no workflows, which must not read as a pass.

The shapes: `nix run`/`nix shell nixpkgs#`, `npx tool` and `npx -y tool`, `pip install` in its `pip3` and `python -m pip` spellings, `pipx run`/`install`, `uvx` and `uv tool run`, `go install …@latest`, `cargo install` without `--locked`, `curl`/`wget … | sh`, and `uses: action@main`/`@master`/`@latest`. Not covered on purpose: `apt-get install` and its kin fetch the runner's system libraries at the runner image's pinned release, which is not a registry the repository could lock. A reviewed exception carries `# check-pins: allow` on its line.

Because the pattern lives in a script beside the workflows rather than in one, nothing in it can match its own source line — the inline form had to spell every alternative with a quantifier the literal text could not satisfy (`pip +install ` rather than `pip install `), or the guard reddened the repository on the commit that introduced it. That trick is still the right one for any check that greps a set of files it belongs to; the secret gate uses it for exactly that reason.

## When the pinned tool moves

A formatter or linter update that changes its opinion lands **in the same commit as the reformat it demands** — lockfile bump plus style change together. Landing either half alone leaves the repo red between them: old tool rejects the new spelling, new tool rejects the old. This is also why the bump cascade verifies with the real build workflow — an opinion change surfaces as a red verify on the bump branch, where a human resolves it as one commit, instead of as a broken default branch.
