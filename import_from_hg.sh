#!/bin/bash

if [ -z "${PYTHON:-}" ]; then
	for python in python3 python /usr/bin/python3; do
		if command -v "$python" >/dev/null 2>&1 && \
			"$python" -c 'from mercurial.scmutil import revsymbol' >/dev/null 2>&1; then
			PYTHON="$python"
			break
		fi
	done
fi

if [ -z "${PYTHON:-}" ]; then
	echo "Could not find a Python interpreter with the Mercurial module available." >&2
	exit 1
fi

export PYTHON

# Import the complete upstream manifest, including the vendor-supplied OSTC3
# packer and its runtime files at tools/. Do not add path filters here: these
# files are required by the repository-relative Windows packaging workflow.
# The hg "default" branch has one genuine orphan head (hg r626,
# be8787f2034d..., "compass3 support for 3.01 branch"): a dead-end commit
# based on the older 3.01 release that was never merged back and never
# continued. hg-fast-export only supports a single head per named branch,
# so --ignore-unnamed-heads plus the head2branch plugin is used to give
# that orphan head its own git branch (compass3-3.01-orphan) instead of
# silently dropping it.
exec ../fast-export/hg-fast-export.sh -r ~/hg/hwos_code/ -A ./authors.txt \
	--ignore-unnamed-heads \
	--plugin head2branch=compass3-3.01-orphan,be8787f2034d9d439a9dafff56a8d0083d0eb6b6
