# Checks that mean something

## Falsifiability — every check is proven able to fail

A check that has never been red is a decoration: nobody knows whether it guards anything. The discipline, applied every time a check is born:

- **Red first.** A new check runs against the pre-fix state, or against a deliberately broken input, and is watched failing — *then* the code that turns it green lands. When a check is adopted into a repo whose state already violates it (a stale version number, a drifted list), that first red run on the real violation is the proof; only then align the state.
- **Checkers ship self-tests.** A lint harness runs itself against known-bad fixtures (`tests/fixtures/must-fail.*`) and exits nonzero unless the fixtures fail. A pipeline that passes a file with an unclosed quote would also pass a broken template, and its green runs would mean nothing.
- **Extractors refuse to find nothing.** A drift check that parses flags, commands or names out of a file fails loudly when its regex matches zero items — a broken extractor must not read as "no drift".
- **Whole-line assertions on generated text.** `grep -qxF`, not substring matches: two similar outputs (a Debian URL that prefixes the generic one, a heading that contains another) make substring checks pass for the wrong branch, provably.
- **Un-mute before diagnosing.** When one platform fails where the rest pass, the first move is removing the `2>/dev/null` from the pipeline in question — an older tool rejecting newer syntax vanishes into muted stderr and presents as "empty output".
- **Probe the mechanism, never a proxy.** A feature-detection check must measure the thing the code actually depends on. Asking `wc -m` whether a locale works, when `bash` does the counting downstream, held until Ubuntu swapped coreutils implementations and the proxy started answering for a locale bash never got.

## Falsifying a test suite

Asking whether a suite would notice the code breaking — and the harness that answers it by breaking guards on purpose — belongs to the [tests](https://github.com/rokokol/tests-skill) skill, and lives there in full. Nothing about it is repeated here, because two accounts of one thing disagree within a month.

## Two checkers worth copying

Both live in [`templates/`](../templates/). `no-secrets.sh` is a skeleton, and carries the warning in its header: **copying it proves nothing**. The mechanism is reusable; the knowledge is not, and the property that makes it worth running is local — the copy must have been falsified in its own repository. `check-skill.sh` has no local knowledge to add, so it is copied verbatim — and it falsifies itself on every run, which is the only way a file that travels alone can stay proven.

### `no-secrets.sh` — the gate at the tracked-file boundary

`.gitignore` keeps a file out; this keeps a value out of a file that belongs in the repo. Both are needed, and the leak that matters is usually the second: a real token pasted into a config default, a doc or a test fixture. It greps **tracked files only** (`git ls-files`, `-I` so a byte sequence inside an image is not a finding), one branch per shape so the message names what was found, and it exits 0 with `nothing tracked yet` on an empty repository rather than reading as a pass by accident.

Most of it is universal and belongs in every copy: PEM private key headers whatever the algorithm label says; forge and registry tokens (`ghp_`, `github_pat_`, `glpat-`, `npm_`, `pypi-`, `hf_`, `dckr_pat_`); model-provider keys (`sk-ant-`, `sk-proj-`, `sk-svcacct-`, `sk-or-v1-`, the legacy 48-character `sk-`, Google's `AIza`, `gsk_`, `r8_`); cloud and SaaS credentials (AWS key ids, `GOCSPX-`, Slack `xox?-` and webhook URLs, `sk_live_`, SendGrid, Mailgun, Twilio, DigitalOcean, Doppler, Linear, Telegram bot tokens); and anything JWT-shaped, which is how a Supabase service key or a session bearer arrives when pasted whole. Under all of them sits the catch-all for providers with no distinctive prefix: a secret-shaped key assigned a real value. Per-repo shapes — a service's session cookie, whole paths that must never be tracked — go in the two `EXAMPLE` sections.

**Every pattern must be unable to match its own source line.** The gate greps the tracked files, and its own file is one of them: a literal prefix followed by a bracket expression is safe (`sk-ant-` then `[A-Za-z0-9_-]{80,}` cannot match the text `[A-Za-z0-9_-]{80,}`), a bare literal is not. Keep that property when adding a shape, or the gate reddens the repository on the very commit that introduces it.

Falsify it by planting one value of each shape and watching it go red on every one. This skill does that in `check-templates.sh`: a throwaway git repository, the template copied in and tracked, first a clean run — which is also the self-match test, since the gate is now scanning its own source — then one generated value per shape, each on its own tracked file, and the gate must report it under that shape's own name: a value caught only by some other, over-broad pattern means the pattern meant for it is dead, and "it went red" alone would not tell. The planted bodies are generated rather than committed: a literal key-shaped string in a fixture is a real finding for every scanner that reads the repository, and a fixture that cannot be pushed is not a fixture.

### `check-skill.sh` — the gate a skill repository needs

A skill fails in ways no test in the repository it documents would notice. Malformed frontmatter, a name with an underscore or a capital, a description past the loader's limit — and the agent never loads the file at all, silently. A reference nothing links to is never read, so it rots while looking maintained. A moved heading leaves a link that resolves to nothing for a reader who is not there to complain. The gate asks all three of one repository, `check-skill.sh [-n NAME] [DIR]`, and exits on the first finding with a message that names it.

- **SKILL.md loads.** The frontmatter opens the file and is closed; `name`, `description` and `license` are present and non-empty; the name is lowercase letters, digits and single hyphens, at most 64 characters, and equals `-n NAME` — what the readme and the install symlink call the skill — when given; the description is at most 1024 *characters*, counted by dropping UTF-8 continuation bytes rather than trusting the locale, so a Cyrillic trigger word counts once.
- **Every reference is reached.** A walk from SKILL.md follows relative links transitively — SKILL.md may delegate to a reference that links on — and every file under `references/` must be in the reached set. Only a link counts, not a mention of the file's name in prose, and only a link from SKILL.md or a reference: README.md and CHANGELOG.md are for people, so a reference the readme alone points at is still unreached. A `references/` directory with nothing in it fails too — the extractor refuses to find nothing.
- **Every link resolves.** In SKILL.md, README.md, CHANGELOG.md and every reference, each relative link target exists, and each `#anchor` matches a heading in the target the way GitHub would slug it: lowercased, punctuation dropped (the Unicode dashes and quotes included), spaces to hyphens, duplicates suffixed `-1`, `-2`. Links inside code fences and code spans are text, not links, and are left alone.
- **Each of those is able to fail, every run.** The script copies the repository, plants one defect — no frontmatter, an unclosed one, a missing key, an invalid name, a name the symlink disagrees with, an oversized description, an orphan reference, a dead link, a dead anchor — and runs itself on the copy, requiring red *for that defect's own reason*. Two controls run beside them: a faithful copy must pass, and a link inside a code fence must not be treated as one. This is why the file can be copied verbatim without the warning the secret gate carries: a copy proves itself in its own repository each time it is run.

It needs bash 3.2 and POSIX tools only, so it runs on a macOS runner unchanged. What it deliberately leaves to other skills: whether the readme hard-wraps its paragraphs belongs to the create-readme skill's checker, and what a changelog looks like to the [versioning](https://github.com/rokokol/versioning-skill) skill's `check-changelog.sh`; a repository's gate runs all three side by side.

## One source of truth per list

Every list CI consults lives in exactly one place; everything else reads it or is checked against it:

- **Lint file lists** live in the build system's own check (a flake check, a make target, a package.json script); the CI job *runs that check* instead of repeating the command with its own copy of the list. Two hand-maintained lists of "files we lint" will disagree within a month.
- **The version** lives in one machine-readable file, and CI cross-checks it against the one place it cannot read from — the changelog. Which repositories have a version at all, where it lives, what the changelog looks like in either case and how a release is cut belong to the [versioning](https://github.com/rokokol/versioning-skill) skill, and are not restated here; its `check-changelog.sh` takes any changelog and is what a job runs. What stays a CI fact: this is a gate on pull requests for repos that ship a version, and this skill is not one of them, which is why `check-templates.sh` does not run it on itself.
- **Hand-written mirrors are allowed, drift-checked.** Shell completions, documented command tables, README flag lists may be spelled by hand for quality — provided a check diffs them against the source of truth and fails on divergence, in both directions.
