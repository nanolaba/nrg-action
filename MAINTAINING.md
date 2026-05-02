# Maintaining nrg-action

Notes for maintainers of this repository. Users should read [`README.md`](./README.md) instead.

## Releasing

Releases of this composite action are cut by tagging a commit on `main`. Two tag families exist:

- **Major-floating** — `v1` (force-pushed to point at the latest release of the v1 line).
- **Minor-pinned** — `v1.0`, `v1.2`, `v1.3`, … (immutable, point at one commit).

Workflow for a new release:

1. Make sure `main` is green.
2. Tag the new minor (e.g. `git tag v1.3 && git push origin v1.3`).
3. Force-move the floating major: `git tag -f v1 && git push origin v1 --force`.
4. **Bump the canonical SHA in docs** — see below.
5. Create the GitHub release notes.

## Why the docs pin a commit SHA

`README.md` and every workflow under `examples/` reference the action by its **commit SHA**, not its tag:

```yaml
- uses: nanolaba/nrg-action@9fae0216ed0c828f520e555912776ca624d84fb5  # v1
```

This is a deliberate supply-chain hardening pattern (see [Hardening notes](./README.md#hardening-notes) in the README). Anyone copy-pasting the canonical example gets a tag-immutable pin out of the box. The trailing `# v1` comment is there so humans (and Renovate/Dependabot) know which major it tracks.

The cost is that **every release moves `v1`, and every pinned SHA in docs goes stale**. Five places to keep in sync:

- `README.md` — Quickstart, Recommended workflow, Validate-only, Open-a-PR variant, Multi-file projects, Skipping setup-java, plus the "Current canonical SHA" callout.
- `examples/recommended.yml`
- `examples/basic.yml`
- `examples/check-on-pr.yml`
- `examples/auto-commit.yml`

Plus the `nrg-version: '1.2'` pin in the recommended example — bump separately when the upstream NRG CLI cuts a new minor.

## Bumping the SHA

Run [`scripts/bump-action-sha.sh`](./scripts/bump-action-sha.sh) after step 3 of the release workflow:

```bash
./scripts/bump-action-sha.sh           # uses current `v1` tag
./scripts/bump-action-sha.sh v1.3      # bumps to a specific tag
```

The script:

1. Resolves the SHA of the given tag (default `v1`).
2. Replaces `nanolaba/nrg-action@<old-sha>` with the new SHA across `README.md` and `examples/*.yml`.
3. Updates the "Current canonical SHA" callout in `README.md` to reference the most-specific same-commit tag (e.g. `v1.3` rather than `v1`).

Review with `git diff`, then commit:

```bash
git add -A
git commit -m "docs: bump pinned nrg-action SHA to <sha> (v1.3)"
git push
```

## CI safety net: `sha-drift.yml`

If anyone forgets step 4, the [`sha-drift`](./.github/workflows/sha-drift.yml) workflow will catch it. It runs on every push to `main` and every PR that touches `README.md` or `examples/`, resolves the current `v1` SHA from the upstream repo via `git ls-remote`, and fails the build if any pinned SHA in docs differs.

That means: after step 3 of the release process, `main` will be **red until step 4 lands**. This is intentional — it's the forcing function that prevents stale-docs bug reports.

If the workflow is ever flaky (e.g. `git ls-remote` rate-limited, GitHub mirror lag), the right fix is to investigate the cause, not to skip the check.
