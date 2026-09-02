# Pinning — a job's behavior changes only when the repo changes

An unpinned tool lookup is a mirror-fate test: `nix run nixpkgs#shfmt`, `npx prettier@latest`, `pip install ruff`, `go install tool@latest` all resolve to whatever the registry serves that morning, and the job goes red — or worse, green against different behavior — for no change in the repo. Real cases that paid for this rule: a formatter minor release that reversed its own spacing opinion (shfmt 3.14 vs 3.13 on `((!x))`), a Go tool whose `@latest` was a 2018 tag resolving fresh dependencies too new for the distro's compiler, and a network daemon whose new version renamed the nftables chains a routing test asserted.

## The rules

- **Actions by version, watched.** `uses: actions/checkout@v7` — a major tag, not `@master` — with dependabot's `github-actions` ecosystem on weekly, so the pin moves by PR, not by surprise.
- **Toolchains and linters from the repo's own lockfile.** Whatever the ecosystem's pinned entrypoint is — `nix develop -c <tool>` (the dev shell is the pinned toolbox), `npm ci` + `npx --no-install`, `cargo run --locked`, a `uv`/`poetry` lock — the tool version is decided by a committed file, and updating it is a diff someone reviews (or the [bump cascade](bump-cascade.md) lands on green).
- **A guard step enforces it** — greps the workflows for the unpinned patterns of the repo's ecosystem and fails the build on a match, so the rule survives the next contributor:

```yaml
- name: CI tools come from the lock, not the registry
  run: |
    if grep -rEn 'nix (run|shell) nixpkgs#|npx +[a-z@.-]|pip +install |go +install .*@latest' .github/workflows; then
      echo "unpinned registry lookup in a workflow — pin the tool via the repo's lockfile" >&2
      exit 1
    fi
```

Tune the pattern list to the ecosystem; keep the step's name stable so it reads as policy, not as a stray grep.

**The guard greps the workflows — including its own line**, which is why every sub-pattern above is written the way it is. A literal one like `pip install ` would match the guard step carrying it and redden the repo on itself the moment it landed. The fix is a quantifier the literal text cannot satisfy: the regex `pip +install ` does not match the text `pip +install `, because after `pip` the text has a space and then `+`, where the regex demands `install`; `npx +[a-z@.-]` does not match `npx +[a-z@.-]` for the same reason. Alternation groups like `nix (run|shell) nixpkgs#` are safe as written — the parentheses are grouping, not text.

Then falsify the guard like any other check, and keep the falsification: this skill's `check-templates.sh` reads the pattern *out of the template* (never spelling it a second time), requires it to match `tests/fixtures/unpinned-workflow.yml`, and requires it **not** to match the template that carries it. Both halves have been watched failing. A guard that has only ever been green may simply be matching nothing.

## When the pinned tool moves

A formatter or linter update that changes its opinion lands **in the same commit as the reformat it demands** — lockfile bump plus style change together. Landing either half alone leaves the repo red between them: old tool rejects the new spelling, new tool rejects the old. This is also why the bump cascade verifies with the real build workflow — an opinion change surfaces as a red verify on the bump branch, where a human resolves it as one commit, instead of as a broken default branch.
