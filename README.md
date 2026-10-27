# hwOS firmware source and build helpers

This working repository is a local Git conversion of the heinrichsweikamp
`hwOS` Mercurial source, maintained with
[`hg-fast-export`](https://github.com/frej/fast-export). Its local import
branches retain the original converted history. A separate orphan branch,
`github/main`, is prepared as a clean public snapshot for a GitHub clone and
Windows build. See [`doc/publishing.md`](doc/publishing.md) before publishing.

## Provenance

- Upstream (real, remote, Mercurial): `https://code.heinrichsweikamp.com/public/hwos_code`
- Read-only local mirror of that upstream: `~/hg/hwos_code` (a plain `hg`
  clone; `hg paths` in it points at the URL above)
- This repository: a git conversion of `~/hg/hwos_code`, for local
  development/inspection with git tooling. Its import branches must not be
  pushed; `github/main` is the separately prepared publication snapshot and
  may be pushed only as described in [`doc/publishing.md`](doc/publishing.md).

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

These tooling/doc files live only on the `development` branch (see below),
never on the branches `hg-fast-export` manages directly.

## Branch mapping

`hg-fast-export` exports one git branch per named hg branch, with hg's
`default` branch renamed to git's `master` (its usual convention, used
unchanged here, matching `~/git/ostc4`):

| hg branch                 | git branch                |
|----------------------------|----------------------------|
| `default`                  | `master`                   |
| `new_screen_layout`         | `new_screen_layout`        |
| public GitHub snapshot      | `github/main`              |
| `ClaudeDive_Translations`   | `ClaudeDive_Translations`  |

`master`, `new_screen_layout`, and `ClaudeDive_Translations` (and
`compass3-3.01-orphan`, below) are **pristine, hg-fast-export-managed
mirrors**. `github/main` is not an import branch: it is a deliberately
history-free publication snapshot and must never be passed to
`hg-fast-export`. `hg-fast-export` records what it last wrote to each of these
refs and refuses to extend a branch that was "modified outside
hg-fast-export" (i.e. by a manually added commit) on the next incremental
run. So nothing else is ever committed onto them directly.

The sync tooling and this README instead live on a separate `development`
branch, created from `master`'s initial import tip, the same way
`~/git/ostc4`'s GitHub-facing `development` branch sits on top of its
`master` mirror. `development` is the branch normally checked out day to
day. To pick up newly imported upstream commits from `master` (or the other
mirror branches) into `development`, merge/rebase them in deliberately,
same as any other fork workflow:

```sh
git checkout development
git merge master   # or: git rebase master
```

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

Because this orphan head still exists in the hg repository, every run of
`import_from_hg.sh` prints `Error: repository has an unnamed head: hg r626`
to stderr. This is expected and non-fatal: `--ignore-unnamed-heads` is
already in effect, the message is printed unconditionally regardless, and
`sync_from_hg.sh`'s own pre-flight check (not this message) is what decides
whether it is safe to proceed.

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
   ever move refs, they never touch the working tree. In normal use this is
   run from `development`, whose ref `hg-fast-export` never touches, so this
   step is a no-op; it only matters if `master` (or another mirror branch)
   happens to be checked out directly.
5. Updates `base_upstream_revision.txt` and commits that one file, only if
   the hg tip actually moved. This commit always lands on whatever branch
   was checked out when the script was run, which should be `development`.

Run `./import_from_hg.sh` directly (without `sync_from_hg.sh`) only if you
want the raw, low-level import step without the safety checks or the
`base_upstream_revision.txt` bookkeeping -- e.g. while debugging a new
orphan-head situation before wiring up a permanent fix in
`import_from_hg.sh`.

### Do not

- Do not add a remote from, or push, an import branch (`master`,
  `development`, `new_screen_layout`, `ClaudeDive_Translations`, or
  `compass3-3.01-orphan`). When publication is authorised, first switch to
  `github/main`, then add the publication remote and push only that branch as
  described in [`doc/publishing.md`](doc/publishing.md).
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
  against the checked-out `development` branch here with
  `diff -rq --exclude=.hg --exclude=.git`: identical, modulo the git-only
  tooling files added on `development`.
- Confirming `git rev-list --all | sort -u | wc -l` reports exactly 660 (the
  imported hg changesets) plus the number of local, `development`-only
  commits (check with
  `git rev-list development ^master ^new_screen_layout
  ^ClaudeDive_Translations ^compass3-3.01-orphan --count`), with no
  duplicates or silently dropped hg commits. Deliberately not hard-coding
  the combined total here: it grows by one every time a new
  `development`-only commit is added, so a fixed number would go stale
  again, as it already did once.
- Spot-checking commit metadata (hash, author, author email, date/timezone,
  message) for the hg tip and for the `compass3-3.01-orphan` head against
  the equivalent `hg log` output.
- Confirming `master`, `new_screen_layout`, `ClaudeDive_Translations`, and
  `compass3-3.01-orphan` still point at exactly the commits `hg-fast-export`
  produced (i.e. unmodified by the tooling commit living only on
  `development`), so a later incremental `sync_from_hg.sh` run does not hit
  `hg-fast-export`'s "modified outside hg-fast-export" guard.
