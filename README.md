# Nanolaba Readme Generator — GitHub Action

Generate multi-language README/Markdown files from a single `.src.md` template, in CI, with one workflow step.

<!-- Marketplace badge omitted until the action is published.
     Re-add after publication:
     [![Marketplace](https://img.shields.io/badge/marketplace-nrg--action-blue?logo=github)](https://github.com/marketplace/actions/nanolaba-readme-generator)
-->
[![Latest NRG release](https://img.shields.io/github/v/release/nanolaba/readme-generator)](https://github.com/nanolaba/readme-generator/releases)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue)](./LICENSE)

This action is a thin composite wrapper around the [NRG CLI](https://github.com/nanolaba/readme-generator). On each run it sets up Java (optional), downloads the requested NRG release zip, extracts `nrg.jar`, and invokes it via `java -cp nrg.jar com.nanolaba.nrg.NRG …` against the templates you list. No Maven, no local Java install, no language requirements on the consuming repository — if a project authors its README via NRG, this action regenerates or verifies it on every push.

## Quickstart

```yaml
- uses: actions/checkout@v4
- uses: nanolaba/nrg-action@18c37a356bcde3a6ced8fa9e6fea173b1de5c460  # v1
  with:
    file: README.src.md
```

Full secure-by-default example: [`examples/recommended.yml`](./examples/recommended.yml). For why production workflows pin to a commit SHA and scope permissions per-job, see [Hardening notes](#hardening-notes).

## Inputs

| Name | Description | Default |
|---|---|---|
| `file` | Path to the `.src.md` template (relative to `working-directory`). Use `files` for multiple. | — |
| `files` | Multi-line list of `.src.md` templates (one per line). Mutually exclusive with `file`. | — |
| `charset` | Source file encoding. | `UTF-8` |
| `mode` | Operation mode: `generate`, `check`, or `validate`. | `generate` |
| `check-paths` | Multi-line list of glob patterns (one per line) limiting which generated outputs `mode: check` compares against on-disk files. Requires `mode: check`. | — |
| `root` | Directory the templates are confined to: imports, descriptors and output files must stay inside it. Needs NRG `v1.3` or newer. | nearest ancestor with `.git` |
| `sandbox` | `'true'` for templates you do not trust — for example on `pull_request` from forks: templates cannot read environment variables and remote imports are refused. Needs NRG `v1.4` or newer. | `'false'` |
| `stale-translations-base` | Git revision to compare the templates with, e.g. `${{ github.event.pull_request.base.sha }}`. The step fails when some languages changed since it and others did not (an outdated translation). Needs `fetch-depth: 0` on checkout and NRG `v1.4` or newer. | — |
| `nrg-version` | NRG release tag (e.g. `v1.4`) or `latest`. | `latest` |
| `nrg-sha256` | Expected sha256 of the downloaded release zip; a mismatch fails the run before the jar is executed. Use with a fixed `nrg-version`. | — |
| `java-version` | JDK version for `actions/setup-java`. Ignored when `setup-java=false`. | `17` |
| `java-distribution` | JDK distribution for `actions/setup-java`. | `temurin` |
| `setup-java` | Whether the action should install Java itself. Set to `'false'` if you set up Java in a previous step. | `true` |
| `log-level` | NRG log verbosity: `trace`, `debug`, `info`, `warn`, or `error`. | `info` |
| `working-directory` | Directory in which NRG runs. | `.` |

`mode` semantics:

- `generate` — write `README.md`, `README.ru.md`, … to disk. Default.
- `check` — read-only verification. Exits non-zero with a unified diff on stderr if disk content does not match what NRG would generate. Use on pull requests.
- `validate` — scan the template for authoring mistakes (unknown widgets and widget parameters, undeclared language markers, missing imports, unbalanced blocks, missing translations; NRG `v1.4` adds "did you mean" hints). Fails on errors, not on warnings. No files written.

## Outputs

| Name | Description |
|---|---|
| `version` | Resolved NRG version (e.g. `v1.0`). Useful when `nrg-version=latest`. |
| `changed-files` | Newline-separated list of files written or modified by NRG. |

## Examples

### Recommended workflow

The canonical pattern: regenerate `README.md` / `README.*.md` on every push to `main`, and on pull requests run a read-only drift check that fails the build if a contributor edited a generated file directly. One workflow file, two jobs, secure defaults — drop it in as `.github/workflows/nrg.yml`:

```yaml
name: Regenerate READMEs
on:
  push:
    branches: [main]
    paths:
      - 'README.src.md'
      - '.github/workflows/nrg.yml'
  pull_request:
    paths:
      - 'README.src.md'
      - 'README.md'
      - 'README.*.md'
      - '.github/workflows/nrg.yml'
permissions:
  contents: read
jobs:
  regenerate:
    if: github.event_name == 'push'
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
      - uses: nanolaba/nrg-action@18c37a356bcde3a6ced8fa9e6fea173b1de5c460  # v1
        with:
          file: README.src.md
          nrg-version: '1.4'
      - name: Commit regenerated READMEs
        run: |
          paths=("README.md" "README.*.md" ":(exclude)README.src.md")
          status="$(git status --porcelain -- "${paths[@]}")"
          if [ -n "$status" ]; then
            changed=$(printf '%s\n' "$status" | sed 's/^...//' | sed 's/^/  - /')
            git config user.name "github-actions[bot]"
            git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
            git add -A -- "${paths[@]}"
            git commit -m "docs: regenerate READMEs from README.src.md" \
              -m $'Files updated:\n'"$changed"
            git push
          fi

  drift-check:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: nanolaba/nrg-action@18c37a356bcde3a6ced8fa9e6fea173b1de5c460  # v1
        with:
          file: README.src.md
          mode: check
          nrg-version: '1.4'
```

See [`examples/recommended.yml`](./examples/recommended.yml).

> **Current canonical SHA:** `18c37a356bcde3a6ced8fa9e6fea173b1de5c460` resolves to `v1.4` (latest at the time of writing). Bump it from the [latest release](https://github.com/nanolaba/nrg-action/releases/latest) when you upgrade.

### Hardening notes

Three things in the workflow above deviate from a naive scaffold. CodeRabbit and similar review bots flag all three on PRs that lack them — and a "simplification" by a contributor will trip the same flags again. Keep them:

1. **Per-job `permissions`, not top-level.** The workflow opens with `permissions: contents: read`. Only the `regenerate` job upgrades to `contents: write`, and only because it pushes a commit. The `drift-check` job stays read-only — narrowest token possible for a CI step that touches a PR.
2. **Action pinned to a commit SHA, not a tag.** `nanolaba/nrg-action@<SHA>  # v1` is immune to tag re-pointing. `@v1` floats, so a compromised release could substitute a malicious commit under the same tag and your workflow would pick it up silently. The trailing `# v1` comment is for humans — Dependabot and Renovate can both bump the SHA when `v1` advances.
3. **Glob paths with a pathspec exclude, not a hardcoded language list.** `paths=("README.md" "README.*.md" ":(exclude)README.src.md")` covers any future language added to `nrg.languages` (e.g. `README.de.md`) without further edits, and the `:(exclude)` keeps the source template out of the auto-commit. A static list like `git add README.md README.ru.md` silently skips new languages until someone notices.

### Verifying the NRG download

Pinning the action to a SHA does not pin the NRG jar the action downloads and runs. Two layers cover that:

- **Release checksum (automatic).** NRG releases from `v1.3` on publish `readme-generator-X.Y.zip.sha256` next to the zip. The action downloads it and refuses a zip that does not match. For older releases it prints the checksum of what it downloaded.
- **Your own pin (strongest).** Fix `nrg-version` and pass the checksum you expect in `nrg-sha256`. The comparison then does not depend on anything stored next to the zip:

```yaml
- uses: nanolaba/nrg-action@18c37a356bcde3a6ced8fa9e6fea173b1de5c460  # v1
  with:
    file: README.src.md
    nrg-version: '1.4'
    nrg-sha256: ff9ccd7efee599299c4d02f847a36bb3c3471720722837b0d87a56f039aff38a
```

### Validate-only

Run the validator against templates on every PR. No files are written; the build fails if any diagnostic is reported:

```yaml
name: Validate templates
on:
  pull_request:
    paths: ['**/*.src.md']
permissions:
  contents: read
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: nanolaba/nrg-action@18c37a356bcde3a6ced8fa9e6fea173b1de5c460  # v1
        with:
          file: README.src.md
          mode: validate
          nrg-version: '1.4'
```

See [`examples/check-on-pr.yml`](./examples/check-on-pr.yml) for a `mode: check` variant.

### Open a PR instead of pushing

If branch protection blocks a direct `git push` to `main`, open a pull request with [`peter-evans/create-pull-request`](https://github.com/peter-evans/create-pull-request) instead. Permissions are scoped to the job that needs them, and the `add-paths` glob mirrors the canonical workflow:

```yaml
name: Regenerate README and open PR
on:
  push:
    branches: [main]
    paths: ['**/*.src.md']
permissions:
  contents: read
jobs:
  regenerate:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    steps:
      - uses: actions/checkout@v4
      - id: nrg
        uses: nanolaba/nrg-action@18c37a356bcde3a6ced8fa9e6fea173b1de5c460  # v1
        with:
          file: README.src.md
          nrg-version: '1.4'
      - uses: peter-evans/create-pull-request@v6
        with:
          commit-message: 'docs: regenerate README from src'
          title: 'docs: regenerate README'
          branch: nrg/regenerate-readme
          delete-branch: true
          add-paths: |
            README.md
            README.*.md
            :(exclude)README.src.md
```

See [`examples/auto-commit.yml`](./examples/auto-commit.yml).

## Multi-file projects

Pass a heredoc list to the `files:` input (one path per line). All files are processed in a single action invocation; the jar is downloaded once:

```yaml
- uses: nanolaba/nrg-action@18c37a356bcde3a6ced8fa9e6fea173b1de5c460  # v1
  with:
    files: |
      README.src.md
      docs/CONTRIBUTING.src.md
```

`file` and `files` are mutually exclusive — set exactly one.

## Skipping the built-in setup-java

If the surrounding workflow already installs Java (for example, for a Maven build), you can opt out of the action's own `actions/setup-java` step. Composite-action inputs are strings, so use the quoted `'false'`, not the YAML boolean:

```yaml
- uses: actions/setup-java@77dd5b2ce225ea11469928ac317850245a74ae78  # v6.2.0
  with:
    distribution: temurin
    java-version: '21'
- uses: nanolaba/nrg-action@18c37a356bcde3a6ced8fa9e6fea173b1de5c460  # v1
  with:
    file: README.src.md
    setup-java: 'false'
```

## Pinning the action version

- `@<full-sha>  # v1` (recommended) — pinned to one commit and unaffected by re-tagging. Dependabot and Renovate both keep this current automatically. This is the form the [Recommended workflow](#recommended-workflow) uses; the trailing `# v1` comment is just a human-readable marker for the major version.
- `@v1` — auto-updates within the v1 major; you get bug fixes without breaking changes, at the cost of trusting whoever holds the tag. Acceptable for low-stakes repositories.
- `@v1.0` — locked to a single minor; predictable across re-runs at the cost of manual bumps. Still floating relative to a SHA.

## Troubleshooting

- **`Failed to download …`** — verify the `nrg-version` you passed exists at <https://github.com/nanolaba/readme-generator/releases>. The default `latest` resolves via the GitHub API; rate-limit pressure is mitigated by the workflow's `github.token`, but a private fork without that token will hit the 60-requests/hour ceiling.
- **`nrg.jar not found inside …`** — the upstream release zip layout changed. Open an issue at <https://github.com/nanolaba/readme-generator/issues> with the version you tried and your runner OS.
- **Windows runner: `unzip: command not found`** — git-bash on `windows-latest` ships `unzip`, but rare images don't. Workaround: precede the action with a step that installs it (e.g. `choco install unzip`).
- **`mode: check` works locally but fails in CI** — almost always line-ending drift on a `windows-latest` checkout. Add a `.gitattributes` with `* text=auto eol=lf` and re-commit the regenerated files.

## Maintainers

Release process and the `scripts/bump-action-sha.sh` helper are documented in [`MAINTAINING.md`](./MAINTAINING.md).

## License

Apache 2.0 — see [`LICENSE`](./LICENSE).
