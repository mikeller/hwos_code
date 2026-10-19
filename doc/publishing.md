# Preparing a public GitHub publication

## Provenance and scope

The firmware source was imported from the public heinrichsweikamp Mercurial
repository at `https://code.heinrichsweikamp.com/public/hwos_code`. The exact
Mercurial revision from which this local Git mirror began is recorded in
`base_upstream_revision.txt`.

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
- Windows executables and DLLs;
- generated firmware HEX files and build output.

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
