# Pinning — a job's behavior changes only when the repo changes

An unpinned tool lookup is a mirror-fate test: `nix run nixpkgs#shfmt`, `npx prettier@latest`, `pip install ruff`, `go install tool@latest` all resolve to whatever the registry serves that morning, and the job goes red — or worse, green against different behavior — for no change in the repo. Failure modes include a formatter release reversing its spacing opinion, an old `@latest` tag resolving dependencies too new for the compiler, and a daemon release renaming resources a test asserts

## The rules

- **Actions by version, watched.** `uses: actions/checkout@v7` — a major tag, not `@master` — with dependabot's `github-actions` ecosystem on weekly, so the pin moves by PR, not by surprise
- **Toolchains and linters from the repo's own lockfile.** Whatever the ecosystem's pinned entrypoint is — `nix develop -c <tool>` (the dev shell is the pinned toolbox), `npm ci` + `npx --no-install`, `cargo run --locked`, a `uv`/`poetry` lock — the tool version is decided by a committed file, and updating it is a diff someone reviews (or the [bump cascade](bump-cascade.md) lands on green)
- **A guard enforces it** — [`templates/check-pins.sh`](../templates/check-pins.sh), vendored into the repository by the [cascade](bump-cascade.md#vendored-files) and run by the build workflow or by the repo's own gate, greps the workflows for the unpinned shapes and fails on a match, so the rule survives the next contributor:

```yaml
- name: CI tools come from the lock, not the registry
  run: ./check-pins.sh
```

Keep the step's name stable so it reads as policy, not as a stray grep

### The guard is one file, not a grep every repository re-types

An inline `grep -rEn '...' .github/workflows` copied into every build workflow creates one pattern per repository; widening it then requires coordinated edits and old alternatives survive. `check-pins.sh` is the one source: it travels by the [vendoring cascade](bump-cascade.md#vendored-files), and a copy is proven in place — on every run it requires each shape's example line to match that shape on its own, and then, alone in a throwaway workflow, to redden the guard with a finding that quotes it. A lone line going red only proves that something matched, so it is the pairing that keeps a narrowed alternative from surviving behind a neighbour. Every pinned spelling together (`nix develop -c`, `npx --no-install`, `cargo install --locked`, an action at a version tag, a line marked `# check-pins: allow`, a comment) must stay green, and a directory with no workflows must not read as a pass

The shapes are the `shapes` list at the top of the script, each written once beside the line it must catch; that list is the only one, so it is not repeated here. Not covered on purpose: `apt-get install` and its kin fetch the runner's system libraries at the runner image's pinned release, which is not a registry the repository could lock. A reviewed exception carries `# check-pins: allow` on its line

Because the pattern lives in a script beside the workflows rather than in one, nothing in it can match its own source line. A check that greps a set of files it belongs to instead spells every alternative with a quantifier the literal text cannot satisfy, `pip +install ` rather than `pip install `, or it reddens itself

## When the pinned tool moves

A formatter or linter update that changes its opinion lands **in the same commit as the reformat it demands** — lockfile bump plus style change together. Landing either half alone leaves the repo red between them: old tool rejects the new spelling, new tool rejects the old. This is also why the bump cascade verifies with the real build workflow — an opinion change surfaces as a red verify on the bump branch, where a human resolves it as one commit, instead of as a broken default branch
