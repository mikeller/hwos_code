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

### Default OSTC Companion package

The default invocation builds and packages an OSTC Companion container:

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

The default package name identifies the legacy OSTC 3 package format and is
derived from the Git worktree:

```text
build/hwos_ostc3_<sanitised-branch>_<12-char-changeset>_firmware.hex
```

For example, build-only operation is explicit:

```powershell
.\tools\build_hwos.ps1 -BuildOnly
```

`-Ostc3Package` may select another filename. The script rejects a missing
runtime file or malformed packer output. It records the packer path/hash, input
HEX hash, container hash, branch, and changeset in `build-info.txt`.

The container format and packaging workflow have been tested on real hardware,
but each generated firmware image requires validation on its target model.
Installation remains subject to the recovery procedure and dive-safety checks.
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

### Memory budget report and gates

Program flash is the binding constraint on this target: the currently
selected configuration has only a few hundred to a few thousand bytes free out
of the 122,880-byte application budget (`0x00000..0x1DFFF`), and some flash
regions are permanently reserved so their spare space cannot migrate
elsewhere. After every successful link, the script parses `build/hwos.map` and
reports:

- per-flash-block used-to address and spare bytes. Block boundaries are
  derived at build time from the fixed `CODE <address>` anchors in
  `src/Docu/Code-Addresses.txt` and the `CODEPAGE` directives in
  `src/18F87K22_hwos.lkr`, not hardcoded, so a future change to either file
  (for example a `grp15` resize) is picked up automatically. A conditionally
  compiled anchor that this particular build did not emit (for example an
  unused second text-table language) does not fabricate a false, permanently
  empty block;
- per-RAM-bank bytes used and free, derived from the `DATABANK`/`ACCESSBANK`
  directives in the same linker script;
- the resolved extent of the `p2_deco` section (start, end, size): how much
  room the C deco engine has;
- the resolved exclusive end address of the `block_0_code_end` label
  (`src/isr.asm`);
- total application flash used and free against the 122,880-byte budget.

A readable summary is printed to the console, and the same figures are
appended to `build/build-info.txt` as `key=value` lines (`flash_budget_*`,
`flash_block_<n>_*`, `ram_bank_<n>_*`, `p2_deco_*`, `block_0_code_end_*`).

To raise or lower the warn/fail thresholds for a specific investigation:

```powershell
.\tools\build_hwos.ps1 -BuildOnly -FlashSpareWarnBytes 512 -FlashSpareFailBytes 32
```

The build is gated on this report:

- a flash block warns when its spare falls below `-FlashSpareWarnBytes`
  (default 256) and fails below `-FlashSpareFailBytes` (default 0, i.e. an
  actual overflow). Only blocks larger than the warn threshold are gated at
  all: a fixed-width hardware vector (a handful of bytes, always fully used by
  design) can never carry that much spare and would otherwise warn on every
  single build;
- the build fails if `block_0_code_end` resolves beyond the `restore` vector
  (`0x00080`): the label is the exclusive end of the high-priority ISR
  dispatcher, so equality means its final byte is at `0x0007F` and does not
  overlap `restore`. The dispatcher must fit in `0x00008..0x0007F`;
- the build fails if any section is placed at or above the bootloader-reserved
  region (`0x1E000`), before `srec_cat` crops the upload image, so an overflow
  is a build failure instead of a silently truncated HEX file;
- the build fails if any RAM allocation falls outside the GPR ranges declared
  in the linker script (the C18 SFR shadow structures that legitimately live
  in the protected `accesssfr` bank are not GPR allocations and are not
  flagged).

Every one of these gates can be bypassed for a forensic or non-canonical build
with `-BypassMemoryBudgetGates`, consistent with how `-BuildOnly` already
relaxes packaging. A bypassed build still computes and records the full
report; `build-info.txt` additionally records
`memory_budget_gate_bypassed=true` so a bypassed result is traceable.

The source checked in at the time of writing resolves `block_0_code_end` to
exactly `0x00080`. This is an exact fit: the preceding `isr_low` section ends
at `0x0007F`, so it does not overlap the `restore` vector. Any growth that
moves the exclusive end beyond `0x00080` fails the gate.

MPASM's default message level is 0, meaning it reports every message, not
only errors and warnings; the existing `/q` passed to `mpasmx`/`MPASMWIN.exe`
only silences its own console echo; it does not change what MPASM writes to
the `.err`/`.lst` files it always produces in `build/obj/`, and this change
leaves it untouched. `/q` is unrelated to MPLINK's `/w`, which is also
unchanged and only suppresses `.cod`/`.lst` generation, not warnings. The
script now:

- prints the contents of a non-empty `.err` file immediately after each
  `mpasmx`/`mcc18` invocation;
- prints a per-file error/warning/message count summary at the end of the
  run, and the same totals (`asm_diagnostics_total_*`) in `build-info.txt`;
- keeps every `build/obj/*.err` and `*.lst` file instead of discarding them
  (they were already being generated; only their survival past a single
  build is new).

`build/build-info.txt` also records the `mcc18` banner
(`mcc18_banner`) captured by running `mcc18` with no source file, and a
best-effort guess at whether it is running in a licensed or free/Lite mode
(`mcc18_licensed_mode_guess`), since C18 in unlicensed/free mode disables most
optimizations and, with flash this tight, that can be the difference between
an image fitting and not fitting. The exact banner wording has not been
confirmed against a real Windows C18 v3.42 installation at the time of
writing; treat `mcc18_licensed_mode_guess` as a hint to check, not a
certainty, until it has been.

## Linux orchestration of the Windows build

`make build` and `tools/build_hwos.sh` build the currently checked-out committed
state
on the authorised Windows C18 builder, then copy verified artefacts back to the
local checkout. They do not attempt to run C18 on Linux.

The local worktree must be clean and on a branch. The script creates a temporary
Git bundle for that exact branch tip and sends it to the builder, so a locally
committed firmware change can be built without being pushed. It creates an
isolated detached Windows Git worktree from that bundle, runs the canonical
PowerShell script, copies the HEX files, linker map, `build-info.txt`, and the
`build/obj/` diagnostics directory (the retained MPASM/mcc18 `.err`/`.lst`
files) into:

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
package filename.

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
`WINDOWS_BUILDER`, `WINDOWS_REPO`, and `WINDOWS_WORKTREE_ROOT`; none of the
three may contain whitespace, and paths must be absolute Windows paths with
forward slashes. Use a DNS name or SSH alias rather than an address where
possible. A one-off environment assignment overrides the local configuration
without editing it:

```sh
WINDOWS_BUILDER=windows-builder-alias make build
```

`REMOTE_BUILD_CONFIG`, `GIT_REMOTE`, and `ARTIFACT_DIR` are also optional
environment overrides for an alternate local configuration, Git remote, or
artefact retention location.

The Windows host must have PowerShell, Git, C18 v3.42, SRecord, and SSH/SCP
access. The orchestration script never pushes, flashes, uploads, or opens a PR.
It removes the temporary bundle after a successful copy; a failed build retains
the remote worktree for diagnosis as before.

## Explicit OSTC3 installation

`make install` is intentionally separate from `make` and `make build`. It uses
the local `subsurface-downloader`, modelled on OSTC4's firmware-install
workflow, only after it has built or reused the hash-verified OSTC 3-family
package for the exact current committed source state. It never enables
`--force-update-firmware` and does not require a release-validation tag: this
path is for installing a current test build.

The target has no device default until a local configuration supplies one. Copy
the tracked template to the ignored `local.mk` and set an exact Bluetooth
address, following OSTC4's local configuration convention. An explicit
`DEVICE=...` command-line value overrides the local default. The default
downloader selection is vendor `Heinrichs Weikamp`, product `OSTC 3`;
`FIRMWARE_INSTALLER`, `DC_VENDOR`, and `DC_PRODUCT` can be explicitly
overridden for a compatible local downloader.

```sh
cp local.mk.example local.mk
$EDITOR local.mk

make install \
  DEVICE=AA:BB:CC:DD:EE:FF
```

The command rejects an empty or automatic device selector, an uncommitted or
detached source worktree, missing or mismatched provenance metadata, an
unexpected legacy OSTC 3 package name, or a firmware/package hash mismatch
before invoking the downloader. The default downloader selection is Heinrichs
Weikamp / OSTC 3; set `DC_PRODUCT` explicitly only for a compatible legacy
OSTC 3, OSTC 3+, or related-device downloader target. The installer is not run
by normal builds.

| File | Purpose |
| --- | --- |
| `build/hwos.production.hex` | Complete MPLAB-linked Intel HEX output. |
| `build/hwos_tiny.hex` | **Upload artefact for TinyBld.** It contains only `0x00000..0x1DFFF`, matching the existing `tools/crop_hwos_hex.bat` release step. |
| `build/hwos.map` | Linker map for size/address investigation; also the source of the memory budget report. |
| `build/build-info.txt` | Source commit, tool paths/hashes, HEX SHA-256 checksums, the `mcc18` banner/licence-mode guess, the memory budget report, and, when requested, packer/container provenance. |
| `build/obj/*.err`, `build/obj/*.lst` | Retained MPASM/mcc18 per-file diagnostics and listings (see [Memory budget report and gates](#memory-budget-report-and-gates)). |

`make clean` removes only `build/`.

Before installing, keep the source commit and `build-info.txt` with the package
and confirm the target hardware and bootloader accept this firmware. A
successful build proves only that C18 linked and the authorised packer accepted
the image. It does not validate device behaviour or make the test firmware safe
for diving.

## Cloud CI assessment

`development` on GitHub is already the hosted repository; no further
repository migration is needed before CI can be considered. MPLAB C18 is a
legacy licensed toolchain, however, and no redistributable, pinned Linux
installation of it is held in this repository, or could be. A workflow that
silently substituted XC8 could produce a materially different firmware and is
not acceptable, so the C18 firmware link cannot run on a standard hosted
Linux runner, and `.github/workflows/host-checks.yml` deliberately does not
attempt one: it never builds, links, flashes, or uploads firmware, and it
requires no secret.

Instead, `host-checks.yml` runs three checks that need no licence and prove
nothing about the C18 link:

1. **A host build of the C sources.** `src/p2_deco.c`, `src/compass.c` and
   `src/compass_calib.c` already have a cross-compile path for Visual
   C/host GCC (see `src/p2_definitions.h`, lines 47-56, and the `#ifndef
   UNIX` guards around their `#pragma udata`/`#pragma romdata` blocks).
   `make check` compiles all three with
   `gcc -DUNIX -Wall -Wextra -c` into the ignored `build/host-check/`
   directory. It only compiles: it never links and never runs the
   resulting objects, and it writes nothing into the tracked tree. This
   catches outright compile breakage (syntax errors, missing definitions)
   in source that is otherwise never exercised on any toolchain other than
   the Windows C18 build.
2. **`shellcheck`** on `sync_from_hg.sh`, `import_from_hg.sh`, and
   `tools/build_hwos.sh`.
3. **`PSScriptAnalyzer`** (a pinned module version) on
   `tools/build_hwos.ps1`.

**Warning/finding policy.** `-Wall -Wextra` on this 2010s embedded C source
has a pre-existing backlog (23 warnings in `p2_deco.c`, 1 each in
`compass.c` and `compass_calib.c` as of this writing, none of them fixed by
this change). `shellcheck` and `PSScriptAnalyzer` likewise had pre-existing
findings (1 shellcheck style finding in `sync_from_hg.sh`; 8
`PSAvoidUsingWriteHost` findings in `tools/build_hwos.ps1`). None of this is
fixed or suppressed here: fixing deco/compass source under a CI ticket is
out of scope for a dive computer, and `tools/build_hwos.ps1`/
`tools/build_hwos.sh` behaviour must not change either. All three checks
therefore run non-blocking for now: a compile *error* still fails the `make
check` step, but warnings and lint findings are reported in the job log and
do not fail the workflow. Tightening this (for example gating on warning
*count* not increasing, or triaging and fixing the backlog) is a follow-up,
not part of this change, and no warning or finding should be silenced
wholesale when that follow-up happens.

A GitHub Actions workflow for the actual C18 link would still need a
private Windows runner or a licensed Windows VM, containing a pinned C18
v3.42 installation and Windows SRecord. That workflow should run
`powershell -File .\tools\build_hwos.ps1`, retain `build/hwos_tiny.hex`,
`build/hwos.production.hex`, `build/hwos.map`, `build/build-info.txt`, and
`build/obj/*.err`/`*.lst` as CI artefacts, and must not flash or upload
firmware to a device. Pin the VM image and toolchain version and record their
checksums so CI artefacts remain traceable to a source commit. The memory
budget gates above reject an ISR dispatcher that overlaps the restore vector;
a CI job must not pass `-BypassMemoryBudgetGates` routinely to work around
such a failure.

`mikeller/ostc4` already runs GitHub Actions workflows from this same
fleet; `host-checks.yml` follows its action-pinning convention (every
action pinned to a commit SHA, e.g. `actions/checkout`).
