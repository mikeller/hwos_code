#!/bin/bash
# Safely bring this git mirror up to date with the Mercurial source at
# ~/hg/hwos_code (upstream: https://code.heinrichsweikamp.com/public/hwos_code).
#
# What this does, in order:
#   1. Refuses to run if either the hg clone or this git working copy has
#      uncommitted/local changes, to avoid mixing in anything stray.
#   2. Checks that the hg repository's head topology still matches what
#      import_from_hg.sh is prepared to handle (see the comment in that
#      script about the compass3-3.01-orphan head). Aborts with guidance
#      instead of risking a silently mis-imported branch if new, unhandled
#      extra heads show up.
#   3. Runs import_from_hg.sh (incremental; only new hg changesets are
#      exported, including upstream vendor packer/runtime files at tools/, using
#      the state kept in .git/hg2git-*).
#   4. Fast-forwards the currently checked-out branch's working tree/index
#      to match its ref (hg-fast-export only moves refs, it never touches
#      the working tree). If this moved refs/heads/master, prints a hint
#      to merge master into development; it never merges automatically.
#   5. If the hg tip moved, records the new sync point in
#      base_upstream_revision.txt and refreshes hg-fast-export_metadata.zip
#      from .git/hg2git-*, committing both together in one bookkeeping
#      commit so the file never goes stale.
#
# This script never touches the hg clone's working copy, and never
# creates or pushes to any git/hg remote. To actually fetch new changesets
# from the real upstream server first, run (outside of this script):
#   hg -R ~/hg/hwos_code pull
# ('pull' only, deliberately without '-u', so the read-only hg working
# copy is never updated/modified -- hg-fast-export reads the repository
# history directly and does not need the working copy checked out to tip.)

set -euo pipefail

HG_REPO="$HOME/hg/hwos_code"
GIT_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_REV_FILE="$GIT_REPO/base_upstream_revision.txt"
METADATA_FILE="$GIT_REPO/hg-fast-export_metadata.zip"
KNOWN_ORPHAN_HASH="be8787f2034d9d439a9dafff56a8d0083d0eb6b6"

cd "$GIT_REPO"

if [ -n "$(git status --porcelain)" ]; then
	echo "Refusing to sync: $GIT_REPO has uncommitted changes. Commit or stash them first." >&2
	exit 1
fi

if [ -n "$(hg -R "$HG_REPO" status)" ]; then
	echo "Refusing to sync: $HG_REPO has local/uncommitted changes. It must stay a clean, read-only mirror." >&2
	exit 1
fi

if ! command -v zip >/dev/null 2>&1; then
	echo "Refusing to sync: 'zip' is required to refresh $METADATA_FILE and was not found in PATH." >&2
	exit 1
fi

# hg-fast-export can only handle one head per named branch. hwos_code has
# exactly one known, already-handled exception (see import_from_hg.sh).
# If upstream history now contains any other branch with more than one
# head, stop rather than let --ignore-unnamed-heads silently reshuffle a
# branch ref.
unexpected_heads=""
while IFS= read -r branch; do
	heads="$(hg -R "$HG_REPO" heads "$branch" --closed --template '{node}\n')"
	count="$(printf '%s\n' "$heads" | sed '/^$/d' | wc -l)"
	if [ "$branch" = "default" ]; then
		# Expect exactly the tip head plus the known orphan head.
		extra="$(printf '%s\n' "$heads" | sed '/^$/d' | grep -v "^${KNOWN_ORPHAN_HASH}$" | wc -l)"
		if [ "$count" -gt 2 ] || { [ "$count" -eq 2 ] && [ "$extra" -ne 1 ]; } || [ "$count" -eq 1 ]; then
			if [ "$count" -ne 2 ] || ! printf '%s\n' "$heads" | grep -q "^${KNOWN_ORPHAN_HASH}$"; then
				unexpected_heads="${unexpected_heads}${branch}: ${heads}\n"
			fi
		fi
	elif [ "$count" -gt 1 ]; then
		unexpected_heads="${unexpected_heads}${branch}: ${heads}\n"
	fi
done < <(hg -R "$HG_REPO" branches --closed --template '{branch}\n')

if [ -n "$unexpected_heads" ]; then
	echo "Refusing to sync: found branch head(s) that import_from_hg.sh is not prepared for:" >&2
	printf '%b' "$unexpected_heads" >&2
	echo "Investigate with 'hg -R $HG_REPO heads <branch> --closed', then either close the" >&2
	echo "extra head in Mercurial, or add a '--plugin head2branch=<name>,<full-hash>' entry" >&2
	echo "to import_from_hg.sh for it (as already done for compass3-3.01-orphan), before re-running." >&2
	exit 1
fi

echo "== hg tip before import =="
before_tip="$(hg -R "$HG_REPO" log -r tip --template '{rev}:{node}\n')"
echo "$before_tip"

current_branch="$(git symbolic-ref --short HEAD)"
before_master="$(git rev-parse --verify -q refs/heads/master || true)"

./import_from_hg.sh

echo "== syncing working tree of '$current_branch' to its updated ref =="
git reset --hard "refs/heads/$current_branch"

after_master="$(git rev-parse --verify -q refs/heads/master || true)"
if [ "$before_master" != "$after_master" ]; then
	echo "== development is behind master; run: git switch development && git merge master =="
fi

new_tip="$(hg -R "$HG_REPO" log -r tip --template '{rev}:{node}\n')"
old_recorded="$(cat "$BASE_REV_FILE" 2>/dev/null || true)"

if [ "$new_tip" != "$old_recorded" ]; then
	# Refresh the committed hg-to-git import state alongside the sync
	# point, so .git/hg2git-* can always be recovered from the last
	# bookkeeping commit instead of forcing a destructive full
	# re-import if it is ever lost. Build the archive in a temporary file
	# and only stage it, and the new sync point, once that succeeds, so a
	# failed zip never leaves METADATA_FILE missing/truncated or
	# base_upstream_revision.txt staged without a matching archive.
	tmp_dir="$(mktemp -d "$GIT_REPO/.sync-metadata-tmp.XXXXXX")"
	trap 'rm -rf "$tmp_dir"' EXIT
	tmp_metadata="$tmp_dir/$(basename "$METADATA_FILE")"
	(cd "$GIT_REPO" && zip -q -j -X "$tmp_metadata" \
		.git/hg2git-marks .git/hg2git-mapping .git/hg2git-heads .git/hg2git-state)
	mv -f "$tmp_metadata" "$METADATA_FILE"
	rm -rf "$tmp_dir"
	trap - EXIT

	echo "$new_tip" > "$BASE_REV_FILE"
	git add "$BASE_REV_FILE" "$METADATA_FILE"

	git commit -s -m "Record hg upstream sync at hg r${new_tip%%:*}"
	echo "== recorded new sync point: $new_tip =="
else
	echo "== no new hg changesets; base_upstream_revision.txt unchanged =="
fi
