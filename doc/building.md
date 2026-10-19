# Building hwOS firmware

This is firmware for the Microchip PIC18F87K22. It is built with the legacy
Microchip MPLAB C18 compiler, not XC8 or a host C compiler. The source and
linker script have C18-specific pragmas and library dependencies, so changing
toolchains is a separate porting project and is not part of this build path.

## Toolchain

hwOS needs a matched MPLAB C18 **v3.42 or newer** toolchain: `mcc18`,
`mpasmx`, and `mplink`. Use only a licensed Microchip distribution. Do not
substitute XC8, GNU PIC tools, or an MPASM/MPLINK installation from another
release: C18 object and library compatibility is version-sensitive.

The official C18 v3.47 download is a legacy 32-bit Windows installer. The
supported local build path is therefore Windows PowerShell with the official
C18 installation and a Windows-compatible [SRecord](https://srecord.sourceforge.net/)
installation providing `srec_cat.exe`. The C18 installation must include its
own `lib\clib.lib` and `lib\p18F87K22.lib`; those precompiled libraries are
not distributed by this repository.

## Windows build (official C18 v3.47)

Install C18 from Microchip's [SW006011 download page](https://www.microchip.com/en-us/development-tool/sw006011)
and install SRecord for Windows. This script automatically finds a standard
C18 v3.47 installation in either `Program Files` location and finds
`srec_cat.exe` on `PATH`.

From PowerShell at the repository root:

```powershell
.\tools\build_hwos.ps1
```

To select an installation root explicitly:

```powershell
.\tools\build_hwos.ps1 -C18Root 'C:\Program Files\Microchip\mplabc18\v3.47'
```

If tools are elsewhere, pass their exact paths. This avoids depending on
machine-wide environment configuration:

```powershell
.\tools\build_hwos.ps1 `
  -Mcc18 'C:\Program Files\Microchip\mplabc18\v3.47\bin\mcc18.exe' `
  -Mpasm 'C:\Program Files\Microchip\mplabc18\v3.47\mpasm\mpasmx.exe' `
  -Mplink 'C:\Program Files\Microchip\mplabc18\v3.47\bin\mplink.exe' `
  -SrecCat 'C:\Tools\SRecord\srec_cat.exe'
```

The script reports missing tools and C18 headers/libraries before compiling. It
does not alter PATH, install software, flash hardware, or upload firmware.

## POSIX automation

`make build` and `tools/build_hwos.sh` are retained for an existing compatible
C18 installation. No Microchip-hosted Linux C18 v3.47 installer has been
verified, so the Windows build above is the supported acquisition path. The
POSIX script accepts explicit `MCC18`, `MPASM`, `MPLINK`, and `SREC_CAT` paths.

```sh
make build MCC18=/path/to/mcc18 MPASM=/path/to/mpasmx MPLINK=/path/to/mplink SREC_CAT=/path/to/srec_cat
```

The build compiles every top-level `src/*.asm` and `src/*.c` source, links them
with `src/18F87K22_hwos.lkr`, and writes these untracked files:

| File | Purpose |
| --- | --- |
| `build/hwos.production.hex` | Complete MPLAB-linked Intel HEX output. |
| `build/hwos_tiny.hex` | **Upload artefact for TinyBld.** It contains only `0x00000..0x1DFFF`, matching the existing `tools/crop_hwos_hex.bat` release step. |
| `build/hwos.map` | Linker map for size/address investigation. |
| `build/build-info.txt` | Source commit and SHA-256 checksums for the two HEX files. |

`make clean` removes only `build/`.

Before uploading, keep the source commit and `build-info.txt` with the HEX and
confirm the target hardware and bootloader accept this firmware. A successful
build proves only that C18 linked the image. It does not validate device
behaviour and this script never uploads firmware.

## Cloud CI assessment

This Git checkout is deliberately a local mirror with no Git remote. It cannot
run hosted CI in its current form. More importantly, MPLAB C18 is a legacy
licensed toolchain and no redistributable, pinned Linux installation is held in
this repository. A workflow that silently substituted XC8 could produce a
materially different firmware and is not acceptable.

If this source is later hosted in a CI-capable repository, use a private
Windows runner or licensed Windows VM containing a pinned C18 v3.47
installation and Windows SRecord. The workflow should run
`powershell -File .\tools\build_hwos.ps1`, retain `build/hwos_tiny.hex`,
`build/hwos.production.hex`, `build/hwos.map`, and `build/build-info.txt` as
CI artefacts, and must not flash or upload firmware to a device. Pin the VM
image/toolchain version and record their checksums so CI artefacts remain
traceable to a source commit.
