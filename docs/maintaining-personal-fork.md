# Maintaining the Personal Fork

## Purpose

This repository is a personal fork of the upstream Kaset project at
[`sozercan/kaset`](https://github.com/sozercan/kaset). It keeps upstream code
available while maintaining personal features as a separate, reviewable commit
series.

## Remotes

The expected Git remotes are:

- `upstream`: the official `sozercan/kaset` repository;
- `origin`: the personal GitHub repository.

Verify the configured URLs before fetching or pushing:

```bash
git remote -v
```

## Branch Model

### `main`

`main` mirrors the latest accepted upstream `main`. Personal features should
not be developed directly on this branch.

Keeping `origin/main` aligned with `upstream/main` provides a clean comparison
base and makes future upstream updates easier to audit.

### `huynguyen-features`

`huynguyen-features` is the long-lived personal integration branch. It contains
the custom features that should remain available after upstream advances,
including local guest playlists, local-build update isolation, the dismissible
sign-in sheet, and other accepted personal changes.

Keep each customization in a focused commit where practical. This makes
conflict resolution and selective rollback easier.

### `feat/*`

Use short-lived `feat/*` topic branches for isolated feature development and
verification. Create them from the current personal integration branch when
the new feature depends on existing personal behavior:

```bash
git switch huynguyen-features
git switch -c feat/example-feature
```

After review and verification, integrate the topic branch into
`huynguyen-features` using the Git workflow chosen for that feature. Delete the
topic branch only after its commits are safely retained on the integration
branch and remote.

## Synchronizing Upstream

Update the clean `main` branch first:

```bash
git fetch upstream
git switch main
git rebase upstream/main
git push origin main
```

Then rebase the personal integration branch onto the updated `main`:

```bash
git switch huynguyen-features
git rebase main
```

Review and verify the rebased result before pushing it. A rebase rewrites the
personal branch's commit IDs, so do not force-push unless the branch update is
intentional and explicitly approved.

## Conflict Resolution

When an upstream change conflicts with `huynguyen-features`, the intended
behavior of the personal features has priority:

1. Understand the upstream behavior before resolving the conflict.
2. Preserve the intended personal behavior instead of silently removing,
   disabling, or replacing the feature.
3. Adapt the personal implementation to the new upstream architecture instead
   of restoring obsolete upstream code.
4. If the upstream change makes a personal feature incompatible or requires
   changing its behavior, ask the human before proceeding.
5. Keep unrelated user changes and untracked files untouched.
6. Run the relevant build, tests, and static checks after the rebase.

Compare the completed integration branch with upstream:

```bash
git diff upstream/main...huynguyen-features
```

This comparison should contain only intentional personal commits and any
follow-up compatibility changes required by newer upstream code.

## Before Pushing

At minimum, inspect the branch and working tree:

```bash
git status
git log --oneline --decorate upstream/main..HEAD
git diff --check upstream/main...HEAD
```

Run the repository's normal build and test checks when code changed. Do not run
UI tests without explicit approval.
