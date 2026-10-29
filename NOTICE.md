# Notice

This repository is a Git mirror and working fork of the heinrichs weikamp
hwOS firmware source, maintained upstream in Mercurial at
`https://code.heinrichsweikamp.com/public/hwos_code`. There is no
repository-wide licence and no `LICENSE` file; file-level notices govern. See
[`doc/publishing.md`](doc/publishing.md) for the full licensing and
publication position.

Third-party binaries redistributed under `tools/`, retained as published by
the upstream project or by this fork's build tooling:

- `tools/QtCore4.dll`, `tools/QtGui4.dll`, and `tools/QtSvg4.dll` are Qt 4
  runtime libraries, covered by their LGPL/GPL terms. Source is available
  from the Qt Project (`https://www.qt.io/`).
- `tools/srec_cat.exe` is from the SRecord project
  (`https://srecord.sourceforge.net/`), covered by the GPL-3.0-or-later and
  LGPL-3.0-or-later terms of that project. Source is available from the
  SRecord project.
- `tools/hex2bin.exe` is hex2bin v2.3 by Jacques Pelletier and contributors
  (`https://sourceforge.net/projects/hex2bin/`), covered by its BSD-2-Clause
  terms.
- `tools/o3pack.exe` is the vendor-supplied OSTC Companion packer, and
  `tools/1.dll` is its co-located runtime library, both retained exactly as
  published by the upstream project. Unlike the entries above, this
  repository holds no licence for either file; see
  [`doc/firmware-packaging.md`](doc/firmware-packaging.md) for the build and
  redistribution limits that follow from that.

No additional rights are asserted by this mirror over any of the above, or
over any other upstream-published file it retains.
