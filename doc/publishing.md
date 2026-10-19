# Preparing a public GitHub publication

## Provenance and scope

The firmware source was imported from the public heinrichsweikamp Mercurial
repository at `https://code.heinrichsweikamp.com/public/hwos_code`. The latest
Mercurial revision imported into this local Git mirror is recorded in
`base_upstream_revision.txt`. `sync_from_hg.sh` updates the file when it
imports a newer upstream revision.

This repository has no repository-wide licence file. Individual source files
may contain their own copyright and licence notices. Publishing remains subject
to confirmation that the copyright holders authorise the chosen GitHub
publication and licence. Do not add a licence or imply a broader permission
without that confirmation.

## Publication branch

The local mirror contains imported historical commits which include legacy
Windows tooling and firmware images. Those files are deliberately excluded from
the current tree, but deleting them in a later commit does not remove them from
old Git objects.

For that reason, publish only the locally prepared orphan branch
`github/main`. It is a clean snapshot for GitHub and contains no imported
history. Do **not** publish `--all`, `master`, `development`, or the
hg-fast-export-managed branches.

The publication snapshot excludes:

- MPLAB C18 libraries and other proprietary toolchain components;
- generated firmware HEX files and build output.

It retains the vendor-supplied OSTC3 packaging files imported from upstream at
`tools/o3pack.exe`, `tools/o3pack.bat`, `tools/1.dll`, `tools/QtCore4.dll`,
`tools/QtGui4.dll`, and `tools/QtSvg4.dll`. Their presence in the public
upstream Mercurial manifest is provenance, not a licence grant. Confirm with
the copyright holders that GitHub publication and redistribution are authorised
before pushing this snapshot or a branch that contains them.

A Windows clone obtains MPLAB C18 and SRecord from their authorised sources and
uses `tools/build_hwos.ps1` as documented in `doc/building.md`.

## Human publication steps

After reviewing the branch and creating an empty GitHub repository, run these
commands locally. Substitute the canonical repository URL supplied by GitHub.

```sh
git switch github/main
git remote add origin https://github.com/<owner>/<repository>.git
git push -u origin github/main:main
```

Do not use `git push --all`. It would expose the local import branches and
their historical binary blobs.
