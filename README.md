# hwOS firmware

This is a clean GitHub publication snapshot of the heinrichsweikamp hwOS
firmware source for the PIC18F87K22, with reproducible local build helpers.

## Build on Windows

Use a licensed installation of Microchip MPLAB C18 v3.47 and Windows SRecord,
then run:

```powershell
.\tools\build_hwos.ps1
```

The upload artefact is `build/hwos_tiny.hex`. Build output is untracked and
must be retained with `build/build-info.txt` for source and checksum
traceability. The build does not upload or flash firmware.

Detailed prerequisites, explicit tool paths, and CI constraints are in
[`doc/building.md`](doc/building.md).

## Source provenance

The source originated in the public heinrichsweikamp Mercurial repository:
<https://code.heinrichsweikamp.com/public/hwos_code>. The imported upstream
revision is recorded in [`base_upstream_revision.txt`](base_upstream_revision.txt).

This public branch is intentionally a snapshot rather than a conversion of the
full Mercurial history. The local import history contained historical Windows
tools and firmware images, which are not included here.

## Licence and safety

No repository-wide licence is asserted by this snapshot. Individual source
files may carry their own copyright and licence notices. Do not infer a broader
licence without confirmation from the relevant copyright holders.

Firmware builds are safety-relevant. A successful build does not validate
behaviour, compatibility with a particular device or bootloader, or suitability
for diving use.
