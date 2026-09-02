# Checks that mean something

## Falsifiability — every check is proven able to fail

A check that has never been red is a decoration: nobody knows whether it guards anything. The discipline, applied every time a check is born:

- **Red first.** A new check runs against the pre-fix state, or against a deliberately broken input, and is watched failing — *then* the code that turns it green lands. When a check is adopted into a repo whose state already violates it (a stale version number, a drifted list), that first red run on the real violation is the proof; only then align the state.
- **Checkers ship self-tests.** A lint harness runs itself against known-bad fixtures (`tests/fixtures/must-fail.*`) and exits nonzero unless the fixtures fail. A pipeline that passes a file with an unclosed quote would also pass a broken template, and its green runs would mean nothing.
- **Extractors refuse to find nothing.** A drift check that parses flags, commands or names out of a file fails loudly when its regex matches zero items — a broken extractor must not read as "no drift".
- **Whole-line assertions on generated text.** `grep -qxF`, not substring matches: two similar outputs (a Debian URL that prefixes the generic one, a heading that contains another) make substring checks pass for the wrong branch, provably.
- **Un-mute before diagnosing.** When one platform fails where the rest pass, the first move is removing the `2>/dev/null` from the pipeline in question — an older tool rejecting newer syntax vanishes into muted stderr and presents as "empty output".
- **Probe the mechanism, never a proxy.** A feature-detection check must measure the thing the code actually depends on. Asking `wc -m` whether a locale works, when `bash` does the counting downstream, held until Ubuntu swapped coreutils implementations and the proxy started answering for a locale bash never got.

## Two checkers worth copying

Both live in [`templates/`](../templates/) as skeletons, and both carry the same warning in their header: **copying one proves nothing**. The mechanism is reusable; the knowledge is not, and the property that makes either worth running is local — the copy must have been falsified in its own repository.

### `falsify.py` — the suite, measured

A test suite tells you the code passes. It does not tell you the suite would notice if the code stopped working, and that is the question worth asking of a green run. The harness answers it mechanically: for each entry in a `DEFECTS` list, replace exactly one line of the implementation with a broken version, rerun the suite, and report `SURVIVED` when it still passes — naming, in operator's terms, the behaviour nobody checks.

The parts that make it trustworthy rather than decorative:

- **The edit is undone in a `finally`, from memory rather than from git** — an interrupted run cannot leave a mutated working tree, and it does not need a clean checkout to be safe to run.
- **`find` must match exactly once.** Zero or many is reported as `stale`, not guessed at: that is how the defect list tells you it has drifted away from the code it describes.
- **A red suite before any edit aborts with a distinct exit code.** Falsification measures the distance between green and red; starting red, there is no distance and every `caught` would be meaningless.
- **Neuter, don't break.** `if False:`, a dropped filter, a widened comparison. A suite that fails on a `SyntaxError` has noticed the syntax, not the behaviour.

The `DEFECTS` list is the repository's own knowledge and never travels with the template. Write one entry per guard as the guard is written, and it doubles as prose documentation of what each guard is *for*.

### `no-secrets.sh` — the gate at the tracked-file boundary

`.gitignore` keeps a file out; this keeps a value out of a file that belongs in the repo. Both are needed, and the leak that matters is usually the second: a real token pasted into a config default, a doc or a test fixture. It greps **tracked files only** (`git ls-files`, `-I` so a byte sequence inside an image is not a finding), one branch per shape so the message names what was found, and it exits 0 with `nothing tracked yet` on an empty repository rather than reading as a pass by accident.

Most of it is universal and belongs in every copy: PEM private key headers whatever the algorithm label says; forge and registry tokens (`ghp_`, `github_pat_`, `glpat-`, `npm_`, `pypi-`, `hf_`, `dckr_pat_`); model-provider keys (`sk-ant-`, `sk-proj-`, `sk-svcacct-`, `sk-or-v1-`, the legacy 48-character `sk-`, Google's `AIza`, `gsk_`, `r8_`); cloud and SaaS credentials (AWS key ids, `GOCSPX-`, Slack `xox?-` and webhook URLs, `sk_live_`, SendGrid, Mailgun, Twilio, DigitalOcean, Doppler, Linear, Telegram bot tokens); and anything JWT-shaped, which is how a Supabase service key or a session bearer arrives when pasted whole. Under all of them sits the catch-all for providers with no distinctive prefix: a secret-shaped key assigned a real value. Per-repo shapes — a service's session cookie, whole paths that must never be tracked — go in the two `EXAMPLE` sections.

**Every pattern must be unable to match its own source line.** The gate greps the tracked files, and its own file is one of them: a literal prefix followed by a bracket expression is safe (`sk-ant-` then `[A-Za-z0-9_-]{80,}` cannot match the text `[A-Za-z0-9_-]{80,}`), a bare literal is not. Keep that property when adding a shape, or the gate reddens the repository on the very commit that introduces it.

Falsify it by planting one value of each shape and watching it go red on every one. This skill does that in `check-templates.sh`: a throwaway git repository, the template copied in and tracked, first a clean run — which is also the self-match test, since the gate is now scanning its own source — then one generated value per shape, each on its own tracked file so a single over-broad pattern cannot cover for a dead one. The planted bodies are generated rather than committed: a literal key-shaped string in a fixture is a real finding for every scanner that reads the repository, and a fixture that cannot be pushed is not a fixture.

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

  This rule is for shipped artifacts — a thing someone installs at a particular version and reports bugs against. A repository that is only ever read at whatever revision is checked out — a skill, a prompt library, a docs-only repo — has no version to be wrong about, so it carries no `VERSION` file and no gate; its changelog is dated instead of numbered. This skill is one of those, which is why `check-templates.sh` does not run the step on itself.
- **Hand-written mirrors are allowed, drift-checked.** Shell completions, documented command tables, README flag lists may be spelled by hand for quality — provided a check diffs them against the source of truth and fails on divergence, in both directions.
