# Building hwOS firmware

This is firmware for the Microchip PIC18F87K22. It is built with the legacy
Microchip MPLAB C18 compiler, not XC8 or a host C compiler. The source and
linker script have C18-specific pragmas and library dependencies, so changing
toolchains is a separate porting project and is not part of this build path.

## Toolchain

The vendor's known-good environment uses MPLAB X **5.10** and the matched
MPLAB C18 **v3.42** toolchain: `mcc18`,
`mpasmx`, and `mplink`. Use only a licensed Microchip distribution. Do not
substitute XC8, GNU PIC tools, or an MPASM/MPLINK installation from another
release: C18 object and library compatibility is version-sensitive.

MPLAB C18 is a legacy 32-bit Windows toolchain. The
supported toolchain path is therefore Windows PowerShell with the official C18
installation and a Windows-compatible [SRecord](https://srecord.sourceforge.net/)
installation providing `srec_cat.exe`. The C18 installation must include its
own `lib\clib.lib` and `lib\p18F87K22.lib`; those precompiled libraries are
not distributed by this repository.

## Windows build (vendor-matched C18 v3.42)

Install C18 v3.42 from Microchip's [SW006011 download page](https://www.microchip.com/en-us/development-tool/sw006011)
and install SRecord for Windows. This script automatically finds a standard
C18 v3.42 installation at `C:\Program Files (x86)\Microchip\mplabc18\v3.42`
and SRecord at `C:\Program Files\srecord\bin\srec_cat.exe`. It deliberately
does not select another C18 release automatically. C18 may
ship its assembler as `mpasm\MPASMWIN.exe` rather than `mpasmx.exe`; both are
discovered. The script does not search `PATH` for any build or packaging tool.

The script rejects a compiler, assembler, or linker outside the same `v3.42`
installation, including tools found incidentally on `PATH`. This prevents a
purported canonical build from mixing C18 releases and libraries.

From PowerShell at the repository root:

```powershell
.\tools\build_hwos.ps1
```

To select an installation root explicitly:

```powershell
.\tools\build_hwos.ps1 -C18Root 'C:\Program Files (x86)\Microchip\mplabc18\v3.42'
```

If tools are elsewhere, pass their exact paths. This avoids depending on
machine-wide environment configuration:

```powershell
.\tools\build_hwos.ps1 `
  -Mcc18 'C:\Program Files (x86)\Microchip\mplabc18\v3.42\bin\mcc18.exe' `
  -Mpasm 'C:\Program Files (x86)\Microchip\mplabc18\v3.42\mpasm\MPASMWIN.exe' `
  -Mplink 'C:\Program Files (x86)\Microchip\mplabc18\v3.42\bin\mplink.exe' `
  -SrecCat 'C:\Program Files\srecord\bin\srec_cat.exe'
```

The script reports missing tools and C18 headers/libraries before compiling. It
does not alter PATH, install software, flash hardware, or upload firmware.

### Default OSTC Companion test package

The default invocation builds and packages an OSTC Companion test container:

```powershell
.\tools\build_hwos.ps1
```

It uses the upstream-tracked vendor `tools/o3pack.exe` and its co-located
`tools/1.dll`, `tools/QtCore4.dll`, `tools/QtGui4.dll`, and
`tools/QtSvg4.dll` runtime files. The script never searches `PATH` for a
packer. An authorised packer in another location may be passed explicitly with
`-O3Pack`.

These vendor binaries are retained from the public upstream Mercurial manifest,
but this repository has no licence grant for them. Do not redistribute them or
publish a branch containing them unless the copyright holders have authorised
that distribution.

The default package name follows the underscore-separated OSTC4 Makefile naming
style and is derived from the Git worktree:

```text
build/hwos_ostc3_<sanitised-branch>_<12-char-changeset>_UNVALIDATED_firmware.hex
```

For example, build-only operation is explicit:

```powershell
.\tools\build_hwos.ps1 -BuildOnly
```

`-Ostc3Package` may select another filename, but it must contain
`UNVALIDATED`. The script rejects a missing runtime file or malformed packer
output. It records the packer path/hash, input HEX hash, container hash, branch,
and changeset in `build-info.txt`.

The resulting encrypted container is only suitable for the vendor-approved
test and recovery procedure. It is not hardware-validated or safe for diving.
`hwos_tiny.hex` remains the separate TinyBld upload image. For format and
authorisation limits, see [firmware-packaging.md](firmware-packaging.md).

### Current verification status

On 27 Oct 2026, the vendor-matched C18 v3.42 toolchain linked the source
cleanly on Windows with MPLINK 4.43. The build used the `3.37` configuration
with `_hwos_tech_2_TR_cave`; `p2_deco` occupied `0x0B000..0x0EF67`, before the
fixed `fonts_data` region at `0x10000`. SRecord reported application data only
through `0x1DFFF`, plus configuration words at `0x300000..0x300005`; no program
data entered the bootloader region at `0x1E000`.

This resolves the earlier v3.47 linker failure as a toolchain mismatch. It does
not validate the generated firmware on hardware or make it suitable for diving.
The checked-in source is 3.37 while the available public reference containers
are 3.38, so their firmware contents are not expected to match.

An explicit `-C18Root` or individual executable parameters can be used for a
non-canonical forensic comparison. Such a result is not a vendor-matched build
and must not be packaged or installed.

## Linux orchestration of the Windows build

`make build` and `tools/build_hwos.sh` build the currently checked-out commit
on the authorised Windows C18 builder, then copy verified artefacts back to the
local checkout. They do not attempt to run C18 on Linux.

The local worktree must be clean, on a branch, and exactly match the branch at
`origin`; the script refuses uncommitted or unpushed commits rather than
silently building different source. It creates an isolated detached Windows Git
worktree for that commit, runs the canonical PowerShell script, copies only the
HEX files, linker map, and `build-info.txt` into:

```sh
build/windows/<full-commit-id>/
```

It verifies the copied full/upload HEX files and, when packaging occurs, the
OSTC3 container against the SHA-256 values in the copied metadata. On success,
it removes only the dedicated builder worktree it created. On a failed remote
build or failed copy, that worktree is retained for diagnosis. Each invocation
uses a unique local `.staging-...` directory and an attempt-specific remote
worktree, so an SSH failure or retained failed worktree cannot block a retry.
Only a fully hash-verified staging directory is promoted to the final commit
directory. An existing verified directory is reused without rebuilding; an
incomplete legacy directory is renamed to `failed-...` and preserved before a
new attempt begins. Failed staging directories contain `failure.log` and, once
SSH was invoked, `remote-build.log`. Because the isolated checkout is detached,
the orchestrator explicitly supplies the local branch and changeset-derived
`UNVALIDATED` package filename.

Inspect retained `build/windows/failed-*` and `build/windows/.staging-*`
directories before removing them manually. `make clean` removes all local build
output, including retained diagnostics; it never touches the Windows builder.

Before the first build, create the ignored local configuration from the tracked
template. It contains the builder hostname or SSH alias and Windows checkout
paths, and must be owned by the current local user. It must not contain
credentials. Use SSH keys and `~/.ssh/config` for authentication.

```sh
cp tools/build_hwos.remote.conf.example tools/build_hwos.remote.conf
$EDITOR tools/build_hwos.remote.conf
```

`tools/build_hwos.remote.conf` is ignored and is required. Its three values are
`WINDOWS_BUILDER`, `WINDOWS_REPO`, and `WINDOWS_WORKTREE_ROOT`; paths must be
absolute Windows paths with forward slashes. Use a DNS name or SSH alias rather
than an address where possible. A one-off environment assignment overrides the
local configuration without editing it:

```sh
WINDOWS_BUILDER=windows-builder-alias make build
```

`REMOTE_BUILD_CONFIG`, `GIT_REMOTE`, and `ARTIFACT_DIR` are also optional
environment overrides for an alternate local configuration, Git remote, or
artefact retention location.

The remote checkout must have an `origin` that can fetch the same pushed branch
and the Windows host must have PowerShell, Git, C18 v3.42, SRecord, and SSH/SCP
access. The orchestration script never pushes, flashes, uploads, or opens a PR.

| File | Purpose |
| --- | --- |
| `build/hwos.production.hex` | Complete MPLAB-linked Intel HEX output. |
| `build/hwos_tiny.hex` | **Upload artefact for TinyBld.** It contains only `0x00000..0x1DFFF`, matching the existing `tools/crop_hwos_hex.bat` release step. |
| `build/hwos.map` | Linker map for size/address investigation. |
| `build/build-info.txt` | Source commit, tool paths/hashes, HEX SHA-256 checksums, and, when requested, packer/container provenance. |

`make clean` removes only `build/`.

Before uploading, keep the source commit and `build-info.txt` with the HEX and
confirm the target hardware and bootloader accept this firmware. A successful
build proves only that C18 linked the image. It does not validate device
behaviour and this script never uploads firmware.

## Cloud CI assessment

`development` on GitHub is already the hosted repository; no further
repository migration is needed before CI can be considered. MPLAB C18 is a
legacy licensed toolchain, however, and no redistributable, pinned Linux
installation of it is held in this repository, or could be. A workflow that
silently substituted XC8 could produce a materially different firmware and is
not acceptable, so the C18 firmware link cannot run on a standard hosted
Linux runner.

A GitHub Actions workflow for the C18 link therefore needs a private Windows
runner or a licensed Windows VM, containing a pinned C18 v3.42 installation
and Windows SRecord. The workflow should run
`powershell -File .\tools\build_hwos.ps1`, retain `build/hwos_tiny.hex`,
`build/hwos.production.hex`, `build/hwos.map`, and `build/build-info.txt` as
CI artefacts, and must not flash or upload firmware to a device. Pin the VM
image and toolchain version and record their checksums so CI artefacts
remain traceable to a source commit.

`mikeller/ostc4` already runs GitHub Actions workflows from this same fleet,
so there is in-fleet precedent for the parts of hwOS CI that do not need
C18, for example lint/format checks on scripts and documentation, or
packaging-script unit tests that do not touch the vendor toolchain. The C18
link step itself remains gated on the private Windows runner above.
