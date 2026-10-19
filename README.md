# hwOS code - local git mirror

This is a local git "fork" of the heinrichsweikamp `hwOS` firmware, built the
same way as `~/git/ostc4` is a git fork of `~/hg/ostc4`: a Mercurial
repository converted and kept in sync with
[`hg-fast-export`](https://github.com/frej/fast-export) (shared checkout at
`~/git/fast-export`, used as `../fast-export` from here).

## Provenance

- Upstream (real, remote, Mercurial): `https://code.heinrichsweikamp.com/public/hwos_code`
- Read-only local mirror of that upstream: `~/hg/hwos_code` (a plain `hg`
  clone; `hg paths` in it points at the URL above)
- This repository: a git conversion of `~/hg/hwos_code`, for local
  development/inspection with git tooling. It has **no git remote
  configured** and must not be pushed anywhere; it exists purely as a local
  working copy.

`~/hg/hwos_code` must be treated as read-only from this repository's point of
view: never commit into it or run `hg update` with outstanding local
changes there. The only thing this git mirror does with it is read its
history to export new changesets.

## Layout

- `import_from_hg.sh` - thin wrapper around `hg-fast-export.sh`, scoped to
  this repository (mirrors `~/git/ostc4/import_from_hg.sh`).
- `sync_from_hg.sh` - the recommended entry point for keeping this mirror up
  to date (see below). Does the import plus the bookkeeping steps that
  `import_from_hg.sh` alone does not.
- `authors.txt` - `hg-fast-export` author-identity normalisation (collapses
  case/formatting variants of the same hg committer, e.g.
  `heinrichs weikamp` / `heinrichsweikamp`, `jDG` / `jdg@air`, the `mh@mh-*`
  hostnames, and the `janos_kovacs`/`Janos Kovacs` casing, into one identity
  each).
- `base_upstream_revision.txt` - `<hg rev>:<full hg node hash>` of the hg
  changeset this mirror was last synced up to. Updated automatically by
  `sync_from_hg.sh` every time new changesets are imported, so it never goes
  stale (unlike the equivalent file in `~/git/ostc4`, which was only ever
  recorded once at the initial import).
- `.gitignore` - carried over from upstream's `.hgignore`.

## Branch mapping

`hg-fast-export` exports one git branch per named hg branch, with hg's
`default` branch renamed to git's `master` (its usual convention, used
unchanged here, matching `~/git/ostc4`):

| hg branch                 | git branch                |
|----------------------------|----------------------------|
| `default`                  | `master`                   |
| `new_screen_layout`         | `new_screen_layout`        |
| `ClaudeDive_Translations`   | `ClaudeDive_Translations`  |

### The `compass3-3.01-orphan` branch

hg's `default` branch has one genuine orphan head: hg r626
(`be8787f2034d9d439a9dafff56a8d0083d0eb6b6`, "compass3 support for 3.01
branch", 23 Jun 2019). It branches off hg r625 (based on the older 3.01
release line) and was never merged back or continued; it has no
descendants and is not an ancestor of the real tip. `hg-fast-export` only
supports a single head per named branch, so without special handling the
import fails with `Error: repository has an unnamed head: hg r626`.

`import_from_hg.sh` resolves this with `--ignore-unnamed-heads` plus the
bundled `head2branch` plugin, giving that one orphan commit its own git
branch, `compass3-3.01-orphan`, instead of dropping it or letting it
corrupt `master`'s ref. All 660 hg changesets as of the initial import are
present as 660 distinct git commits across the four branches above; none
were discarded.

If a *future* upstream sync introduces another branch with more than one
head, `sync_from_hg.sh` detects it up front and refuses to run (see below)
rather than relying on `hg-fast-export`'s undocumented fallback behaviour
for unhandled extra heads.

## Usage

### Pulling new changesets from the real upstream (optional, separate step)

This only touches `~/hg/hwos_code`'s history, never its working copy, and
is entirely separate from converting anything to git:

```sh
hg -R ~/hg/hwos_code pull
```

Deliberately `pull` and not `pull -u`: it fetches new changesets into the
local hg store without touching the checked-out working copy, keeping
`~/hg/hwos_code` read-only/undisturbed in practice. `hg-fast-export` reads
repository history directly, so the working copy never needs to be updated
for the git import to pick up new changesets.

### Importing whatever is in the hg clone into this git mirror

```sh
cd ~/git/hwos_code
./sync_from_hg.sh
```

This:

1. Refuses to run if either `~/hg/hwos_code` or this repository has
   uncommitted changes.
2. Checks the hg branch/head topology against what `import_from_hg.sh` is
   prepared to handle (see "The `compass3-3.01-orphan` branch" above), and
   refuses to continue with guidance if something new and unhandled shows
   up.
3. Runs `import_from_hg.sh` (this step alone is incremental and safe to run
   repeatedly; it reuses the state kept in `.git/hg2git-*` and only
   exports new changesets).
4. Resets the currently checked-out branch's working tree/index to match
   its (possibly advanced) ref -- `hg-fast-export`/`git fast-import` only
   ever move refs, they never touch the working tree.
5. Updates `base_upstream_revision.txt` and commits that one file, only if
   the hg tip actually moved.

Run `./import_from_hg.sh` directly (without `sync_from_hg.sh`) only if you
want the raw, low-level import step without the safety checks or the
`base_upstream_revision.txt` bookkeeping -- e.g. while debugging a new
orphan-head situation before wiring up a permanent fix in
`import_from_hg.sh`.

### Do not

- Do not add a git remote to this repository, push it anywhere, or open a
  pull/merge request from it; it is a local-only working copy.
- Do not `hg commit` or `hg update` with outstanding changes in
  `~/hg/hwos_code`; it must stay a clean mirror of the real upstream so that
  `sync_from_hg.sh`'s pre-flight checks remain meaningful.
- Do not delete `.git/hg2git-marks`, `.git/hg2git-mapping`, `.git/hg2git-heads`,
  or `.git/hg2git-state`. They hold the incremental-import state; losing them
  means the next import either needs `--force` (which re-exports everything
  as new, differently-hashed commits) or careful manual recovery.

## Validating the initial import

The initial import (660/660 hg changesets, 4 branches) was checked by:

- Comparing `hg -R ~/hg/hwos_code` (updated to the `default` branch tip)
  against the checked-out `master` branch here with
  `diff -rq --exclude=.hg --exclude=.git`: identical, modulo the git-only
  tooling files added by this mirror.
- Confirming `git rev-list --all | sort -u | wc -l` reports 660, matching
  the 660 hg changesets, with no duplicates or silently dropped commits.
- Spot-checking commit metadata (hash, author, author email, date/timezone,
  message) for the hg tip and for the `compass3-3.01-orphan` head against
  the equivalent `hg log` output.
