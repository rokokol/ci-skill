# Checks that mean something

## Falsifiability — every check is proven able to fail

A check that has never been red is a decoration: nobody knows whether it guards anything. The discipline, applied every time a check is born:

- **Red first.** A new check runs against the pre-fix state, or against a deliberately broken input, and is watched failing — *then* the code that turns it green lands. When a check is adopted into a repo whose state already violates it (a stale version number, a drifted list), that first red run on the real violation is the proof; only then align the state.
- **Checkers ship self-tests.** A lint harness runs itself against known-bad fixtures (`tests/fixtures/must-fail.*`) and exits nonzero unless the fixtures fail. A pipeline that passes a file with an unclosed quote would also pass a broken template, and its green runs would mean nothing.
- **Extractors refuse to find nothing.** A drift check that parses flags, commands or names out of a file fails loudly when its regex matches zero items — a broken extractor must not read as "no drift".
- **Whole-line assertions on generated text.** `grep -qxF`, not substring matches: two similar outputs (a Debian URL that prefixes the generic one, a heading that contains another) make substring checks pass for the wrong branch, provably.
- **Un-mute before diagnosing.** When one platform fails where the rest pass, the first move is removing the `2>/dev/null` from the pipeline in question — an older tool rejecting newer syntax vanishes into muted stderr and presents as "empty output".
- **Probe the mechanism, never a proxy.** A feature-detection check must measure the thing the code actually depends on. Asking `wc -m` whether a locale works, when `bash` does the counting downstream, held until Ubuntu swapped coreutils implementations and the proxy started answering for a locale bash never got.

## One source of truth per list

Every list CI consults lives in exactly one place; everything else reads it or is checked against it:

- **Lint file lists** live in the build system's own check (a flake check, a make target, a package.json script); the CI job *runs that check* instead of repeating the command with its own copy of the list. Two hand-maintained lists of "files we lint" will disagree within a month.
- **The version** lives in one machine-readable file (`VERSION`); the package metadata reads it, the tools print it, and CI cross-checks the one place it cannot read from — the changelog:

  ```yaml
  - name: VERSION matches CHANGELOG
    run: |
      ver=$(cat VERSION)
      grep -qF "## [$ver]" CHANGELOG.md || {
        echo "VERSION says $ver but CHANGELOG.md has no ## [$ver] heading" >&2
        exit 1
      }
  ```

  The release ritual bumps `VERSION` in the same commit that moves the changelog section, so the check can only pass when both moved together.
- **Hand-written mirrors are allowed, drift-checked.** Shell completions, documented command tables, README flag lists may be spelled by hand for quality — provided a check diffs them against the source of truth and fails on divergence, in both directions.
