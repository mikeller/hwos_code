<#
.SYNOPSIS
Build the hwOS PIC18F87K22 firmware with the Windows MPLAB C18 toolchain.

.DESCRIPTION
Compiles every top-level src/*.asm and src/*.c file with the vendor's MPLAB
C18 v3.42 environment, then crops the linked image to 0x00000..0x1DFFF.
Unless -BuildOnly is given, it then invokes a local or explicitly supplied
vendor-authorised o3pack.exe to make an OSTC Companion container.
The script never flashes or uploads firmware.
#>
[CmdletBinding()]
param(
    [string]$C18Root,
    [string]$Mcc18,
    [string]$Mpasm,
    [string]$Mplink,
    [string]$SrecCat,
    [switch]$BuildOnly,
    [string]$O3Pack,
    [string]$Ostc3Package,
    [string]$SourceBranch,
    [string]$BuildDir = 'build',
    # A flash block is only warned/failed on if its own size exceeds the warn
    # threshold; fixed-width hardware vectors (a handful of bytes each) can
    # never carry this much spare and are reported, but not gated, instead.
    [ValidateRange(0, [int]::MaxValue)]
    [int]$FlashSpareWarnBytes = 256,
    [ValidateRange(0, [int]::MaxValue)]
    [int]$FlashSpareFailBytes = 0,
    # Bypasses every memory-budget gate below (block_0_code_end, bootloader
    # overflow, GPR overflow, flash-spare thresholds) for a forensic or
    # non-canonical build. The report is still computed and still written to
    # build-info.txt, with the bypass itself recorded there.
    [switch]$BypassMemoryBudgetGates
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$SourceDir = Join-Path $RepoRoot 'src'
$Processor = '18F87K22'

if ([System.IO.Path]::IsPathRooted($BuildDir)) {
    $BuildDir = [System.IO.Path]::GetFullPath($BuildDir)
} else {
    $BuildDir = [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $BuildDir))
}
$ObjectDir = Join-Path $BuildDir 'obj'
$DoPackageOstc3 = -not $BuildOnly
if ($BypassMemoryBudgetGates -and $DoPackageOstc3) {
    throw '-BypassMemoryBudgetGates is only permitted with -BuildOnly; non-canonical builds must not produce an OSTC package.'
}

function Resolve-BuildTool {
    param(
        [string]$Name,
        [string]$ConfiguredPath,
        [string[]]$Candidates = @()
    )

    if ($ConfiguredPath) {
        if (Test-Path -LiteralPath $ConfiguredPath -PathType Leaf) {
            return (Resolve-Path -LiteralPath $ConfiguredPath).Path
        }
        throw "Configured $Name executable does not exist: $ConfiguredPath"
    }

    foreach ($Candidate in $Candidates) {
        if ($Candidate -and (Test-Path -LiteralPath $Candidate -PathType Leaf)) {
            return (Resolve-Path -LiteralPath $Candidate).Path
        }
    }

    throw "Required tool '$Name' was not found at its canonical Windows location. Install the vendor-matched MPLAB C18 v3.42 toolchain and Windows SRecord, or provide its explicit script parameter."
}

function Invoke-BuildTool {
    param(
        [string]$Tool,
        [string[]]$Arguments
    )

    # o3pack writes normal progress messages to stderr. Let each native tool's
    # exit status, rather than PowerShell's stderr handling, determine failure.
    $PreviousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $Tool @Arguments
        $ExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $PreviousErrorActionPreference
    }
    if ($ExitCode -ne 0) {
        throw "Command failed with exit code ${ExitCode}: $Tool $($Arguments -join ' ')"
    }
}

function Invoke-ToolForBanner {
    param(
        [string]$Tool,
        [string[]]$Arguments = @()
    )

    # Some legacy tools (mcc18 with no input file) print their version/licence
    # banner and exit non-zero because no compilation happened. That is
    # expected here: only the banner text is wanted, so the exit code is
    # deliberately ignored, unlike Invoke-BuildTool.
    $PreviousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $Output = & $Tool @Arguments 2>&1 | Out-String
    } finally {
        $ErrorActionPreference = $PreviousErrorActionPreference
    }
    return $Output
}

function Get-LinkerScriptMemoryLayout {
    <#
    .SYNOPSIS
    Parses the CODEPAGE/DATABANK/ACCESSBANK directives from the hwOS linker
    script, so flash and RAM boundaries are derived at build time instead of
    being duplicated as literals in this script.
    #>
    param(
        [Parameter(Mandatory)][string]$LinkerScriptPath,
        [Parameter(Mandatory)][string]$ProcessorIncludePath
    )

    $CodePages = [System.Collections.Generic.List[pscustomobject]]::new()
    $RamRegions = [System.Collections.Generic.List[pscustomobject]]::new()

    foreach ($Line in (Get-Content -LiteralPath $LinkerScriptPath)) {
        if ($Line -match '^\s*CODEPAGE\s+NAME=(?<name>\S+)\s+START=0x(?<start>[0-9A-Fa-f]+)\s+END=0x(?<end>[0-9A-Fa-f]+)(?<prot>\s+PROTECTED)?\s*$') {
            $CodePages.Add([pscustomobject]@{
                Name      = $Matches['name']
                Start     = [Convert]::ToInt64($Matches['start'], 16)
                End       = [Convert]::ToInt64($Matches['end'], 16)
                Protected = [bool]$Matches['prot']
            })
        } elseif ($Line -match '^\s*(?:DATABANK|ACCESSBANK)\s+NAME=(?<name>\S+)\s+START=0x(?<start>[0-9A-Fa-f]+)\s+END=0x(?<end>[0-9A-Fa-f]+)(?<prot>\s+PROTECTED)?\s*$') {
            $RamRegions.Add([pscustomobject]@{
                Name      = $Matches['name']
                Start     = [Convert]::ToInt64($Matches['start'], 16)
                End       = [Convert]::ToInt64($Matches['end'], 16)
                Protected = [bool]$Matches['prot']
            })
        }
    }

    if ($CodePages.Count -eq 0) {
        throw "No CODEPAGE directives were found in linker script: $LinkerScriptPath"
    }
    if ($RamRegions.Count -eq 0) {
        throw "No DATABANK/ACCESSBANK directives were found in linker script: $LinkerScriptPath"
    }

    # MPLINK needs SFR_BANKED0 to fit in the historical grp15 range, but the
    # device map reserves 0xF16 and above for SFRs. Derive that boundary from
    # the processor include so the RAM report does not call SFRs free GPR.
    $SfrStart = $null
    foreach ($Line in (Get-Content -LiteralPath $ProcessorIncludePath)) {
        if ($Line -match '^\s*\S+\s+EQU\s+H''(?<addr>[0-9A-Fa-f]+)''') {
            $Address = [Convert]::ToInt64($Matches['addr'], 16)
            if ($Address -ge 0xF00 -and ($null -eq $SfrStart -or $Address -lt $SfrStart)) {
                $SfrStart = $Address
            }
        }
    }
    if ($null -eq $SfrStart) {
        throw "No SFR addresses at or above 0xF00 were found in processor include: $ProcessorIncludePath"
    }

    return [pscustomobject]@{
        CodePages  = $CodePages.ToArray()
        RamRegions = $RamRegions.ToArray()
        SfrStart   = [int64]$SfrStart
    }
}

function Get-FixedCodeAnchor {
    <#
    .SYNOPSIS
    Parses the fixed `<name> CODE 0x<address>` anchors from
    src/Docu/Code-Addresses.txt, including the `(bootloader)` sentinel that
    documents where the bootloader-reserved region begins.
    #>
    param([Parameter(Mandatory)][string]$Path)

    $Anchors = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($Line in (Get-Content -LiteralPath $Path)) {
        if ($Line -match '^(?<name>.+?)\s+CODE\s+0x(?<addr>[0-9A-Fa-f]+)\b') {
            $Anchors.Add([pscustomobject]@{
                Name    = $Matches['name'].Trim()
                Address = [Convert]::ToInt64($Matches['addr'], 16)
            })
        }
    }
    if ($Anchors.Count -eq 0) {
        throw "No fixed CODE anchors were found in: $Path"
    }
    return ($Anchors | Sort-Object Address)
}

function Get-LinkerMapReport {
    <#
    .SYNOPSIS
    Parses the Section Info table, the Program Memory Usage table, and the
    Symbols table out of an MPLINK .map file.
    #>
    param([Parameter(Mandatory)][string]$MapPath)

    $SectionInfo = [System.Collections.Generic.List[pscustomobject]]::new()
    $ProgramUsage = [System.Collections.Generic.List[pscustomobject]]::new()
    $Symbols = @{}
    $Mode = 'none'

    foreach ($Line in (Get-Content -LiteralPath $MapPath)) {
        if ($Line -match '^\s*Section\s+Type\s+Address\s+Location\s+Size(?:\s*\(Bytes\))?\s*$') { $Mode = 'section'; continue }
        if ($Line -match '^\s*Program Memory Usage\s*$') { $Mode = 'usage-pending'; continue }
        if ($Mode -eq 'usage-pending' -and $Line -match '^\s*Start\s+End\s*$') { $Mode = 'usage'; continue }
        if ($Line -match '^\s*Name\s+Address\s+Location\s+Storage\s+File') { $Mode = 'symbols'; continue }
        if ($Line -match '^\s*Symbols - Sorted by Address\s*$') { $Mode = 'symbols'; continue }

        switch ($Mode) {
            'section' {
                if ($Line -match '^\s*(?<name>\S+)\s+(?<type>code|romdata|udata|idata|actrec|near)\s+0x(?<addr>[0-9A-Fa-f]+)\s+(?<loc>program|data)\s+0x(?<size>[0-9A-Fa-f]+)\s*$') {
                    $SectionInfo.Add([pscustomobject]@{
                        Name     = $Matches['name']
                        Type     = $Matches['type']
                        Address  = [Convert]::ToInt64($Matches['addr'], 16)
                        Location = $Matches['loc']
                        Size     = [Convert]::ToInt64($Matches['size'], 16)
                    })
                } elseif ($Line -match '^\s*$' -and $SectionInfo.Count -gt 0) {
                    $Mode = 'none'
                }
            }
            'usage' {
                if ($Line -match '^\s*0x(?<start>[0-9A-Fa-f]+)\s+0x(?<end>[0-9A-Fa-f]+)\s*$') {
                    $ProgramUsage.Add([pscustomobject]@{
                        Start = [Convert]::ToInt64($Matches['start'], 16)
                        End   = [Convert]::ToInt64($Matches['end'], 16)
                    })
                } elseif ($Line -match '^\s*$' -and $ProgramUsage.Count -gt 0) {
                    $Mode = 'none'
                }
            }
            'symbols' {
                if ($Line -match '^\s*(?<name>\S+)\s+0x(?<addr>[0-9A-Fa-f]+)\s+(?<loc>program|data)\s+\S+') {
                    if (-not $Symbols.ContainsKey($Matches['name'])) {
                        $Symbols[$Matches['name']] = [Convert]::ToInt64($Matches['addr'], 16)
                    }
                }
            }
        }
    }

    if ($SectionInfo.Count -eq 0) { throw "No Section Info table was found in linker map: $MapPath" }
    if ($ProgramUsage.Count -eq 0) { throw "No Program Memory Usage table was found in linker map: $MapPath" }

    return [pscustomobject]@{
        Sections     = $SectionInfo.ToArray()
        ProgramUsage = $ProgramUsage.ToArray()
        Symbols      = $Symbols
    }
}

function Get-FlashMemoryBudgetReport {
    <#
    .SYNOPSIS
    Derives per-flash-block used-to/spare figures from the fixed CODE anchors
    and CODEPAGE directives, scoped to the application flash budget that ends
    where the bootloader-reserved region (the `(bootloader)` anchor) begins.
    A candidate anchor only becomes a block boundary if this particular build
    actually placed a section there; a conditionally-compiled anchor (for
    example an unused second text-table language) must not fabricate a false,
    permanently-empty block with misleading spare.
    #>
    param(
        [Parameter(Mandatory)][pscustomobject]$Regions,
        [Parameter(Mandatory)][pscustomobject[]]$Anchors,
        [Parameter(Mandatory)][pscustomobject]$MapReport,
        [Parameter(Mandatory)][int]$WarnBytes
    )

    $BootloaderAnchor = $Anchors | Where-Object { $_.Name -eq '(bootloader)' } | Select-Object -First 1
    if (-not $BootloaderAnchor) {
        throw "Code-Addresses.txt has no '(bootloader)' sentinel entry to derive the application flash budget from."
    }
    $BootloaderStart = [int64]$BootloaderAnchor.Address

    $AppCodePages = $Regions.CodePages | Where-Object { $_.Start -lt $BootloaderStart }
    $CandidateBoundaries = [System.Collections.Generic.List[int64]]::new()
    foreach ($A in ($Anchors | Where-Object { $_.Address -gt 0 -and $_.Address -lt $BootloaderStart })) { $CandidateBoundaries.Add([int64]$A.Address) }
    foreach ($C in $AppCodePages) { $CandidateBoundaries.Add([int64]$C.Start) }

    $OccupiedStarts = [System.Collections.Generic.HashSet[int64]]::new()
    foreach ($Row in ($MapReport.Sections | Where-Object { $_.Location -eq 'program' })) {
        [void]$OccupiedStarts.Add([int64]$Row.Address)
    }

    $Boundaries = [System.Collections.Generic.List[int64]]::new()
    $Boundaries.Add([int64]0)
    foreach ($B in ($CandidateBoundaries | Sort-Object -Unique)) {
        if ($OccupiedStarts.Contains($B)) { $Boundaries.Add($B) }
    }
    $Boundaries.Add($BootloaderStart)
    $Boundaries = $Boundaries | Sort-Object -Unique

    $NameByAddress = @{}
    foreach ($A in $Anchors) { if (-not $NameByAddress.ContainsKey([int64]$A.Address)) { $NameByAddress[[int64]$A.Address] = $A.Name } }
    foreach ($C in $Regions.CodePages) { if (-not $NameByAddress.ContainsKey([int64]$C.Start)) { $NameByAddress[[int64]$C.Start] = "codepage:$($C.Name)" } }

    $Blocks = for ($i = 0; $i -lt ($Boundaries.Count - 1); $i++) {
        $BlockStart = [int64]$Boundaries[$i]
        $BlockEnd = [int64]$Boundaries[$i + 1] - 1
        $Rows = $MapReport.Sections | Where-Object { $_.Location -eq 'program' -and $_.Address -ge $BlockStart -and $_.Address -le $BlockEnd }
        $Measured = ($Rows | ForEach-Object { $_.Address + $_.Size - 1 } | Measure-Object -Maximum).Maximum
        $UsedTo = if ($null -eq $Measured) { $BlockStart - 1 } else { [int64]$Measured }
        $Size = $BlockEnd - $BlockStart + 1
        [pscustomobject]@{
            Name   = if ($NameByAddress.ContainsKey($BlockStart)) { $NameByAddress[$BlockStart] } else { '0x{0:x6}' -f $BlockStart }
            Start  = $BlockStart
            End    = $BlockEnd
            Size   = $Size
            UsedTo = $UsedTo
            Spare  = $BlockEnd - $UsedTo
            Gated  = $Size -gt $WarnBytes
        }
    }

    $Used = ($MapReport.ProgramUsage | Where-Object { $_.End -lt $BootloaderStart } | ForEach-Object { $_.End - $_.Start + 1 } | Measure-Object -Sum).Sum
    if ($null -eq $Used) { $Used = 0 }
    $Used = [int64]$Used

    # The first CODEPAGE after the bootloader area is the device metadata
    # region (idlocs on PIC18F87K22). Only the interval before it can contain
    # application code, so do not mistake protected config/devid/eeprom ranges
    # in the map for a bootloader overflow.
    $ApplicationAddressLimit = $Regions.CodePages | Where-Object { $_.Start -gt $BootloaderStart } | Select-Object -ExpandProperty Start | Sort-Object | Select-Object -First 1
    if ($null -eq $ApplicationAddressLimit) { $ApplicationAddressLimit = [int64]::MaxValue }
    $BootloaderOverflows = @($MapReport.ProgramUsage | Where-Object { $_.Start -lt $ApplicationAddressLimit -and $_.End -ge $BootloaderStart })

    return [pscustomobject]@{
        Blocks              = @($Blocks)
        BudgetTotalBytes    = $BootloaderStart
        BudgetUsedBytes     = $Used
        BudgetFreeBytes     = $BootloaderStart - $Used
        BootloaderStart     = $BootloaderStart
        BootloaderOverflows = $BootloaderOverflows
    }
}

function Get-RamMemoryBudgetReport {
    <#
    .SYNOPSIS
    Derives per-RAM-bank used/free figures directly from the DATABANK and
    ACCESSBANK directives, and flags any data allocation that spills out of
    its own non-protected (GPR) bank. accesssfr is PROTECTED and intentionally
    holds the C18 SFR shadow structures, so allocations that start there are
    not a GPR concern.
    #>
    param(
        [Parameter(Mandatory)][pscustomobject]$Regions,
        [Parameter(Mandatory)][pscustomobject]$MapReport
    )

    $Banks = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($Region in ($Regions.RamRegions | Sort-Object Start)) {
        if ($Region.Start -lt $Regions.SfrStart -and $Region.End -ge $Regions.SfrStart) {
            $Banks.Add([pscustomobject]@{ Name = $Region.Name; Start = $Region.Start; End = $Regions.SfrStart - 1; Protected = $Region.Protected })
            $Banks.Add([pscustomobject]@{ Name = "$($Region.Name):sfr"; Start = $Regions.SfrStart; End = $Region.End; Protected = $true })
        } else {
            $Banks.Add($Region)
        }
    }
    $Banks = $Banks.ToArray()
    $BankReports = foreach ($Bank in $Banks) {
        $Rows = $MapReport.Sections | Where-Object { $_.Location -eq 'data' -and $_.Address -ge $Bank.Start -and $_.Address -le $Bank.End }
        $Measured = ($Rows | ForEach-Object { $_.Address + $_.Size - 1 } | Measure-Object -Maximum).Maximum
        $UsedTo = if ($null -eq $Measured) { $Bank.Start - 1 } else { [int64]$Measured }
        $UsedBytes = [Math]::Max(0, $UsedTo - $Bank.Start + 1)
        $Size = $Bank.End - $Bank.Start + 1
        [pscustomobject]@{
            Name      = $Bank.Name
            Start     = $Bank.Start
            End       = $Bank.End
            Size      = $Size
            UsedBytes = $UsedBytes
            FreeBytes = $Size - $UsedBytes
            Protected = $Bank.Protected
        }
    }

    # MPLINK C18 v3.42 emits SFR_BANKED0 for the PIC18F87K22 SFR interval
    # that overlaps the historical grp15 linker range. It is the only valid
    # allocation in the report's virtual grp15:sfr bank; any other section
    # there is an unsafe use of device registers.
    $AllowedVirtualSfrSections = @('SFR_BANKED0')
    $Violations = @(foreach ($Row in ($MapReport.Sections | Where-Object { $_.Location -eq 'data' -and $_.Size -gt 0 })) {
        $RowEnd = $Row.Address + $Row.Size - 1
        $Bank = $Banks | Where-Object { $Row.Address -ge $_.Start -and $Row.Address -le $_.End } | Select-Object -First 1
        if (-not $Bank) {
            $Row
        } elseif ($Bank.Name -eq 'grp15:sfr' -and ($Row.Name -notin $AllowedVirtualSfrSections -or $RowEnd -gt $Bank.End)) {
            $Row
        } elseif (-not $Bank.Protected -and $RowEnd -gt $Bank.End) {
            $Row
        }
    })

    return [pscustomobject]@{
        Banks      = @($BankReports)
        Violations = $Violations
    }
}

$C18Roots = @()
if ($C18Root) {
    $C18Roots += $C18Root
}
if ($env:C18_ROOT) {
    $C18Roots += $env:C18_ROOT
}
if (-not $C18Root -and -not $env:C18_ROOT) {
    # Heinrichs Weikamp's known-good build environment uses this installation.
    # Do not silently select another C18 release for a canonical build.
    $C18Roots += (Join-Path ([Environment]::GetFolderPath('ProgramFilesX86')) 'Microchip\mplabc18\v3.42')
}
$C18Roots = $C18Roots | Select-Object -Unique

$Mcc18Candidates = @($C18Roots | ForEach-Object { Join-Path $_ 'bin\mcc18.exe' })
$MpasmCandidates = @(
    foreach ($Root in $C18Roots) {
        Join-Path $Root 'mpasm\mpasmx.exe'
        Join-Path $Root 'mpasm\MPASMWIN.exe'
    }
)
$MplinkCandidates = @($C18Roots | ForEach-Object { Join-Path $_ 'bin\mplink.exe' })

$Mcc18 = Resolve-BuildTool -Name 'mcc18' -ConfiguredPath $Mcc18 -Candidates $Mcc18Candidates
# The C18 standard headers are needed by p2_deco.c. Derive them from the
# selected compiler rather than relying on an installer-created MCC_INCLUDE.
$DetectedC18Root = Split-Path -Parent (Split-Path -Parent $Mcc18)
if ((Split-Path -Leaf $DetectedC18Root) -ine 'v3.42') {
    throw "Canonical hwOS builds require MPLAB C18 v3.42. Selected compiler is outside a v3.42 installation: $Mcc18"
}
$Mpasm = Resolve-BuildTool -Name 'mpasmx' -ConfiguredPath $Mpasm -Candidates $MpasmCandidates
$Mplink = Resolve-BuildTool -Name 'mplink' -ConfiguredPath $Mplink -Candidates $MplinkCandidates
$DefaultSrecCat = Join-Path ([Environment]::GetFolderPath('ProgramFiles')) 'srecord\bin\srec_cat.exe'
$SrecCat = Resolve-BuildTool -Name 'srec_cat' -ConfiguredPath $SrecCat -Candidates @($DefaultSrecCat)
foreach ($Tool in @($Mpasm, $Mplink)) {
    $ToolC18Root = Split-Path -Parent (Split-Path -Parent $Tool)
    if ($ToolC18Root -ine $DetectedC18Root) {
        throw "Canonical hwOS builds require all C18 tools from $DetectedC18Root. Selected incompatible tool: $Tool"
    }
}
$C18IncludeDir = Join-Path $DetectedC18Root 'h'
$C18LibraryDir = Join-Path $DetectedC18Root 'lib'
if (-not (Test-Path -LiteralPath $C18IncludeDir -PathType Container)) {
    throw "MPLAB C18 headers were not found beside $Mcc18. Expected directory: $C18IncludeDir"
}
foreach ($Library in @('clib.lib', 'p18F87K22.lib')) {
    if (-not (Test-Path -LiteralPath (Join-Path $C18LibraryDir $Library) -PathType Leaf)) {
        throw "MPLAB C18 library $Library was not found. Expected it in: $C18LibraryDir. Install the complete official C18 toolchain; do not copy a library into this repository."
    }
}

# C18 in unlicensed/free (Lite) mode disables most optimizations, which on
# this flash-constrained target can be the difference between an image
# fitting and not fitting. Capture whatever banner mcc18 prints with no
# source file given; this is the only provenance for which mode produced the
# object files below. Record the verbatim text rather than guessing at its
# exact wording, which has not been confirmed against every C18 v3.42 build.
$Mcc18BannerRaw = Invoke-ToolForBanner -Tool $Mcc18
$Mcc18Banner = (($Mcc18BannerRaw -split '\r?\n') | Where-Object { $_.Trim() } | Select-Object -First 3) -join ' | '
if (-not $Mcc18Banner) { $Mcc18Banner = '(no banner text captured)' }
$Mcc18LicensedModeGuess = -not ($Mcc18Banner -imatch 'lite|free|unlicensed|evaluation|student')

$Git = Get-Command git.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $Git) {
    $Git = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
}
if (-not $Git) {
    throw 'Required tool git was not found on PATH. A Git checkout is required to record the source commit in build-info.txt.'
}

$SourceCommit = ((& $Git.Path -C $RepoRoot rev-parse HEAD) | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or -not $SourceCommit) {
    throw "Unable to determine the source commit in $RepoRoot."
}
$DetectedSourceBranch = ((& $Git.Path -C $RepoRoot branch --show-current) | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or -not $DetectedSourceBranch) {
    $DetectedSourceBranch = 'detached'
}
if (-not $SourceBranch) {
    $SourceBranch = $DetectedSourceBranch
}
$SourceChangeset = ((& $Git.Path -C $RepoRoot rev-parse --short=12 HEAD) | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or -not $SourceChangeset) {
    throw "Unable to determine the source changeset in $RepoRoot."
}
$SafeSourceBranch = [System.Text.RegularExpressions.Regex]::Replace($SourceBranch, '[^A-Za-z0-9._-]+', '-')
if (-not $SafeSourceBranch) {
    throw "Unable to derive a safe package filename from Git branch: $SourceBranch"
}
if (-not $Ostc3Package) {
    $Ostc3Package = "hwos_ostc3_${SafeSourceBranch}_${SourceChangeset}_firmware.hex"
}
if ([System.IO.Path]::IsPathRooted($Ostc3Package)) {
    $Ostc3Package = [System.IO.Path]::GetFullPath($Ostc3Package)
} else {
    $Ostc3Package = Join-Path $BuildDir $Ostc3Package
}

Remove-Item -LiteralPath $ObjectDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $ObjectDir -Force | Out-Null

# MPASM's default message level is 0 (every message, not just errors and
# warnings); /q (line below) only silences its own console echo, it does not
# suppress or change what is recorded in the .err/.lst files it always
# writes. Surface a non-empty .err immediately, and keep every .err/.lst
# (nothing here deletes them again) so tools/build_hwos.sh can copy them back.
function Show-NonEmptyDiagnosticsFile {
    param([string]$SourceName, [string]$ErrFile)
    if ((Test-Path -LiteralPath $ErrFile -PathType Leaf) -and (Get-Item -LiteralPath $ErrFile).Length -gt 0) {
        Write-Host "---- ${SourceName}: $(Split-Path -Leaf $ErrFile) ----"
        Get-Content -LiteralPath $ErrFile | ForEach-Object { Write-Host $_ }
        Write-Host '----'
    }
}

function Get-DiagnosticsFileCount {
    param([string]$ErrFile)
    $Counts = [pscustomobject]@{ Errors = 0; Warnings = 0; Messages = 0 }
    if (Test-Path -LiteralPath $ErrFile -PathType Leaf) {
        foreach ($Line in (Get-Content -LiteralPath $ErrFile)) {
            if ($Line -match '^\s*Error\b') { $Counts.Errors++ }
            elseif ($Line -match '^\s*Warning\b') { $Counts.Warnings++ }
            elseif ($Line -match '^\s*Message\b') { $Counts.Messages++ }
        }
    }
    return $Counts
}

$DiagnosticsSummary = [System.Collections.Generic.List[pscustomobject]]::new()

$Objects = [System.Collections.Generic.List[string]]::new()
Get-ChildItem -LiteralPath $SourceDir -Filter '*.asm' -File | Sort-Object Name | ForEach-Object {
    $Object = Join-Path $ObjectDir ($_.BaseName + '.o')
    $ErrFile = "$ObjectDir\$($_.BaseName).err"
    Write-Host ('ASM  src\{0}' -f $_.Name)
    Push-Location -LiteralPath $SourceDir
    try {
        Invoke-BuildTool -Tool $Mpasm -Arguments @('/q', "/p$Processor", "/o$Object", "/e$ErrFile", "/l$ObjectDir\$($_.BaseName).lst", $_.Name)
    } finally {
        Pop-Location
    }
    Show-NonEmptyDiagnosticsFile -SourceName $_.Name -ErrFile $ErrFile
    $Counts = Get-DiagnosticsFileCount -ErrFile $ErrFile
    $DiagnosticsSummary.Add([pscustomobject]@{ File = $_.Name; Errors = $Counts.Errors; Warnings = $Counts.Warnings; Messages = $Counts.Messages })
    $Objects.Add($Object)
}

Get-ChildItem -LiteralPath $SourceDir -Filter '*.c' -File | Sort-Object Name | ForEach-Object {
    $Object = Join-Path $ObjectDir ($_.BaseName + '.o')
    $ErrFile = "$ObjectDir\$($_.BaseName).err"
    Write-Host ('C18  src\{0}' -f $_.Name)
    Invoke-BuildTool -Tool $Mcc18 -Arguments @("-p=$Processor", "-I=$SourceDir", "-I=$C18IncludeDir", "-fo=$Object", "-fe=$ErrFile", $_.FullName)
    Show-NonEmptyDiagnosticsFile -SourceName $_.Name -ErrFile $ErrFile
    $Counts = Get-DiagnosticsFileCount -ErrFile $ErrFile
    $DiagnosticsSummary.Add([pscustomobject]@{ File = $_.Name; Errors = $Counts.Errors; Warnings = $Counts.Warnings; Messages = $Counts.Messages })
    $Objects.Add($Object)
}

$FullHex = Join-Path $BuildDir 'hwos.production.hex'
$TinyHex = Join-Path $BuildDir 'hwos_tiny.hex'
$MapFile = Join-Path $BuildDir 'hwos.map'
$LinkerScript = Join-Path $SourceDir '18F87K22_hwos.lkr'

Write-Host ('LINK {0}' -f $FullHex)
$LinkArguments = @("/p$Processor", '/w', "/m$MapFile", "/o$FullHex", $LinkerScript)
$LinkArguments += $Objects.ToArray()
# The project script has LIBPATH ., so invoke MPLINK from C18's lib directory.
# The C18 device and runtime libraries stay outside the checkout.
Push-Location -LiteralPath $C18LibraryDir
try {
    Invoke-BuildTool -Tool $Mplink -Arguments $LinkArguments
} finally {
    Pop-Location
}

#region Memory budget report and gates
#
# Program flash is the binding constraint on this target: every figure below
# is derived from the just-produced map file, the fixed CODE anchors in
# src/Docu/Code-Addresses.txt, and the CODEPAGE/DATABANK/ACCESSBANK
# directives in the linker script, never hardcoded, so the report tracks a
# future change to any of those files (for example a grp15 resize)
# automatically.
$CodeAddressesPath = Join-Path $SourceDir 'Docu\Code-Addresses.txt'
$ProcessorInclude = Join-Path $SourceDir 'P18F87K22.INC'
$MemoryRegions = Get-LinkerScriptMemoryLayout -LinkerScriptPath $LinkerScript -ProcessorIncludePath $ProcessorInclude
$FixedAnchors = Get-FixedCodeAnchor -Path $CodeAddressesPath
$MapReport = Get-LinkerMapReport -MapPath $MapFile
$FlashReport = Get-FlashMemoryBudgetReport -Regions $MemoryRegions -Anchors $FixedAnchors -MapReport $MapReport -WarnBytes $FlashSpareWarnBytes
$RamReport = Get-RamMemoryBudgetReport -Regions $MemoryRegions -MapReport $MapReport

$P2DecoSection = $MapReport.Sections | Where-Object { $_.Name -eq 'p2_deco' -and $_.Type -eq 'code' } | Select-Object -First 1

$RestoreAnchor = $FixedAnchors | Where-Object { $_.Name -eq 'restore' } | Select-Object -First 1
if (-not $RestoreAnchor) {
    throw "Code-Addresses.txt has no 'restore' anchor to derive the high-priority ISR dispatcher limit from."
}
$BlockZeroCodeEndSymbol = 'block_0_code_end'
$BlockZeroCodeEndAddress = $MapReport.Symbols[$BlockZeroCodeEndSymbol]

$GateFailures = [System.Collections.Generic.List[string]]::new()
$GateWarnings = [System.Collections.Generic.List[string]]::new()

if ($null -eq $BlockZeroCodeEndAddress) {
    $GateFailures.Add("Symbol '$BlockZeroCodeEndSymbol' (src/isr.asm) was not found in $MapFile; the high-priority ISR dispatcher fit cannot be verified.")
} elseif ($BlockZeroCodeEndAddress -gt $RestoreAnchor.Address) {
    # block_0_code_end is a label after the final dispatcher instruction, so
    # it is an exclusive end address. Equality means that the final byte is
    # at restore - 1 and is safe, albeit with no spare instruction space.
    $GateFailures.Add(('block_0_code_end resolved to 0x{0:X6}, beyond the restore vector at 0x{1:X6}; the high-priority ISR dispatcher overlaps the restore vector.' -f $BlockZeroCodeEndAddress, $RestoreAnchor.Address))
}

if ($FlashReport.BootloaderOverflows.Count -gt 0) {
    foreach ($Row in $FlashReport.BootloaderOverflows) {
        $GateFailures.Add(('Program memory range 0x{0:X6}..0x{1:X6} overlaps the bootloader-reserved region starting at 0x{2:X6}.' -f $Row.Start, $Row.End, $FlashReport.BootloaderStart))
    }
}

if ($RamReport.Violations.Count -gt 0) {
    foreach ($Row in $RamReport.Violations) {
        $GateFailures.Add(('RAM allocation {0} at 0x{1:X4} (size {2}) falls outside the GPR ranges declared in {3}.' -f $Row.Name, $Row.Address, $Row.Size, $LinkerScript))
    }
}

foreach ($Block in ($FlashReport.Blocks | Where-Object { $_.Gated })) {
    if ($Block.Spare -lt $FlashSpareFailBytes) {
        $GateFailures.Add(('Flash block {0} (0x{1:X6}..0x{2:X6}) has only {3} byte(s) spare, below the fail threshold of {4}.' -f $Block.Name, $Block.Start, $Block.End, $Block.Spare, $FlashSpareFailBytes))
    } elseif ($Block.Spare -lt $FlashSpareWarnBytes) {
        $GateWarnings.Add(('Flash block {0} (0x{1:X6}..0x{2:X6}) has only {3} byte(s) spare, below the warn threshold of {4}.' -f $Block.Name, $Block.Start, $Block.End, $Block.Spare, $FlashSpareWarnBytes))
    }
}

Write-Host "`nMemory budget report (derived from $MapFile):"
Write-Host ('  Flash budget: {0} used, {1} free, of {2} bytes (0x00000-0x{3:X5})' -f $FlashReport.BudgetUsedBytes, $FlashReport.BudgetFreeBytes, $FlashReport.BudgetTotalBytes, ($FlashReport.BootloaderStart - 1))
foreach ($Block in $FlashReport.Blocks) {
    Write-Host ('    {0,-22} start=0x{1:X6} end=0x{2:X6} used_to=0x{3:X6} spare={4,6}{5}' -f $Block.Name, $Block.Start, $Block.End, $Block.UsedTo, $Block.Spare, $(if ($Block.Gated) { '' } else { ' (fixed-width, not gated)' }))
}
if ($P2DecoSection) {
    $P2DecoEnd = $P2DecoSection.Address + $P2DecoSection.Size - 1
    Write-Host ('  p2_deco (C deco engine): start=0x{0:X6} end=0x{1:X6} size={2} bytes' -f $P2DecoSection.Address, $P2DecoEnd, $P2DecoSection.Size)
} else {
    Write-Host '  p2_deco section was not found in this build (informational only; not gated).'
}
if ($null -ne $BlockZeroCodeEndAddress) {
    Write-Host ('  block_0_code_end (exclusive): 0x{0:X6} (must not exceed restore at 0x{1:X6})' -f $BlockZeroCodeEndAddress, $RestoreAnchor.Address)
}
Write-Host '  RAM banks:'
foreach ($Bank in $RamReport.Banks) {
    Write-Host ('    {0,-12} start=0x{1:X4} end=0x{2:X4} used={3,5} free={4,5}{5}' -f $Bank.Name, $Bank.Start, $Bank.End, $Bank.UsedBytes, $Bank.FreeBytes, $(if ($Bank.Protected) { ' (protected, not GPR)' } else { '' }))
}

foreach ($Warning in $GateWarnings) {
    Write-Warning $Warning
}

$MemoryBudgetGateBypassed = $false
if ($GateFailures.Count -gt 0) {
    if ($BypassMemoryBudgetGates) {
        $MemoryBudgetGateBypassed = $true
        Write-Warning 'Memory budget gate failure(s) bypassed by -BypassMemoryBudgetGates; this build is not a canonical release candidate:'
        foreach ($Failure in $GateFailures) { Write-Warning "  $Failure" }
    } else {
        foreach ($Failure in $GateFailures) { Write-Host "FAIL: $Failure" }
        throw "Memory budget gate(s) failed; rerun with -BypassMemoryBudgetGates for a forensic/non-canonical build, or free up the flagged space."
    }
}

$MemoryBudgetMetadata = [System.Collections.Generic.List[string]]::new()
$MemoryBudgetMetadata.Add("flash_budget_total_bytes=$($FlashReport.BudgetTotalBytes)")
$MemoryBudgetMetadata.Add("flash_budget_used_bytes=$($FlashReport.BudgetUsedBytes)")
$MemoryBudgetMetadata.Add("flash_budget_free_bytes=$($FlashReport.BudgetFreeBytes)")
$MemoryBudgetMetadata.Add("flash_spare_warn_threshold_bytes=$FlashSpareWarnBytes")
$MemoryBudgetMetadata.Add("flash_spare_fail_threshold_bytes=$FlashSpareFailBytes")
$MemoryBudgetMetadata.Add("flash_block_count=$($FlashReport.Blocks.Count)")
for ($i = 0; $i -lt $FlashReport.Blocks.Count; $i++) {
    $Block = $FlashReport.Blocks[$i]
    $N = $i + 1
    $MemoryBudgetMetadata.Add(("flash_block_{0}_name={1}" -f $N, $Block.Name))
    $MemoryBudgetMetadata.Add(("flash_block_{0}_start=0x{1:x6}" -f $N, $Block.Start))
    $MemoryBudgetMetadata.Add(("flash_block_{0}_end=0x{1:x6}" -f $N, $Block.End))
    $MemoryBudgetMetadata.Add(("flash_block_{0}_used_to=0x{1:x6}" -f $N, $Block.UsedTo))
    $MemoryBudgetMetadata.Add(("flash_block_{0}_spare_bytes={1}" -f $N, $Block.Spare))
    $MemoryBudgetMetadata.Add(("flash_block_{0}_gated={1}" -f $N, $Block.Gated.ToString().ToLowerInvariant()))
}
$MemoryBudgetMetadata.Add("ram_bank_count=$($RamReport.Banks.Count)")
for ($i = 0; $i -lt $RamReport.Banks.Count; $i++) {
    $Bank = $RamReport.Banks[$i]
    $N = $i + 1
    $MemoryBudgetMetadata.Add(("ram_bank_{0}_name={1}" -f $N, $Bank.Name))
    $MemoryBudgetMetadata.Add(("ram_bank_{0}_start=0x{1:x4}" -f $N, $Bank.Start))
    $MemoryBudgetMetadata.Add(("ram_bank_{0}_end=0x{1:x4}" -f $N, $Bank.End))
    $MemoryBudgetMetadata.Add(("ram_bank_{0}_used_bytes={1}" -f $N, $Bank.UsedBytes))
    $MemoryBudgetMetadata.Add(("ram_bank_{0}_free_bytes={1}" -f $N, $Bank.FreeBytes))
    $MemoryBudgetMetadata.Add(("ram_bank_{0}_protected={1}" -f $N, $Bank.Protected.ToString().ToLowerInvariant()))
}
if ($P2DecoSection) {
    $MemoryBudgetMetadata.Add('p2_deco_section_found=true')
    $MemoryBudgetMetadata.Add(("p2_deco_start=0x{0:x6}" -f $P2DecoSection.Address))
    $MemoryBudgetMetadata.Add(("p2_deco_end=0x{0:x6}" -f ($P2DecoSection.Address + $P2DecoSection.Size - 1)))
    $MemoryBudgetMetadata.Add(("p2_deco_size_bytes={0}" -f $P2DecoSection.Size))
} else {
    $MemoryBudgetMetadata.Add('p2_deco_section_found=false')
}
if ($null -ne $BlockZeroCodeEndAddress) {
    $MemoryBudgetMetadata.Add(("block_0_code_end_address=0x{0:x6}" -f $BlockZeroCodeEndAddress))
    $MemoryBudgetMetadata.Add('block_0_code_end_is_exclusive=true')
}
$MemoryBudgetMetadata.Add(("block_0_code_end_limit_address=0x{0:x6}" -f $RestoreAnchor.Address))
$MemoryBudgetMetadata.Add("memory_budget_gate_bypassed=$($MemoryBudgetGateBypassed.ToString().ToLowerInvariant())")

$TotalAsmErrors = ($DiagnosticsSummary | Measure-Object -Property Errors -Sum).Sum
$TotalAsmWarnings = ($DiagnosticsSummary | Measure-Object -Property Warnings -Sum).Sum
$TotalAsmMessages = ($DiagnosticsSummary | Measure-Object -Property Messages -Sum).Sum
if ($null -eq $TotalAsmErrors) { $TotalAsmErrors = 0 }
if ($null -eq $TotalAsmWarnings) { $TotalAsmWarnings = 0 }
if ($null -eq $TotalAsmMessages) { $TotalAsmMessages = 0 }
Write-Host "`nAssembler/compiler diagnostics summary:"
foreach ($Entry in ($DiagnosticsSummary | Where-Object { $_.Errors -gt 0 -or $_.Warnings -gt 0 -or $_.Messages -gt 0 })) {
    Write-Host ('  {0,-24} errors={1} warnings={2} messages={3}' -f $Entry.File, $Entry.Errors, $Entry.Warnings, $Entry.Messages)
}
Write-Host ('  Total: {0} file(s) compiled, {1} error(s), {2} warning(s), {3} message(s).' -f $DiagnosticsSummary.Count, $TotalAsmErrors, $TotalAsmWarnings, $TotalAsmMessages)
$MemoryBudgetMetadata.Add("asm_diagnostics_total_errors=$TotalAsmErrors")
$MemoryBudgetMetadata.Add("asm_diagnostics_total_warnings=$TotalAsmWarnings")
$MemoryBudgetMetadata.Add("asm_diagnostics_total_messages=$TotalAsmMessages")
#endregion Memory budget report and gates

# TinyBld must not receive the logo/program area beginning at 0x1E000.
Write-Host ('CROP {0}' -f $TinyHex)
Invoke-BuildTool -Tool $SrecCat -Arguments @($FullHex, '-Intel', '-crop', '0x00000', '0x1E000', '-o', $TinyHex, '-Intel')

if (-not (Test-Path -LiteralPath $TinyHex -PathType Leaf) -or (Get-Item -LiteralPath $TinyHex).Length -eq 0) {
    throw "Generated upload HEX is empty or missing: $TinyHex"
}
if (-not (Select-String -LiteralPath $TinyHex -Pattern '^:00000001FF$' -Quiet)) {
    throw "Generated upload HEX has no Intel HEX EOF record: $TinyHex"
}

$FullHash = (Get-FileHash -LiteralPath $FullHex -Algorithm SHA256).Hash.ToLowerInvariant()
$TinyHash = (Get-FileHash -LiteralPath $TinyHex -Algorithm SHA256).Hash.ToLowerInvariant()

$PackagingMetadata = @('ostc3_package=not_created_build_only')
if ($DoPackageOstc3) {
    $CanonicalC18Root = [System.IO.Path]::GetFullPath((Join-Path ([Environment]::GetFolderPath('ProgramFilesX86')) 'Microchip\mplabc18\v3.42'))
    if ([System.IO.Path]::GetFullPath($DetectedC18Root) -ine $CanonicalC18Root) {
        throw 'OSTC Companion packaging requires the canonical MPLAB C18 v3.42 installation. Use -BuildOnly for forensic comparisons.'
    }
}
if ($DoPackageOstc3) {
    $DefaultO3Pack = Join-Path $RepoRoot 'tools\o3pack.exe'
    if ($O3Pack) {
        if (-not (Test-Path -LiteralPath $O3Pack -PathType Leaf)) {
            throw "Configured o3pack executable does not exist: $O3Pack"
        }
        $O3Pack = (Resolve-Path -LiteralPath $O3Pack).Path
    } elseif (Test-Path -LiteralPath $DefaultO3Pack -PathType Leaf) {
        $O3Pack = (Resolve-Path -LiteralPath $DefaultO3Pack).Path
    } else {
        throw "OSTC Companion packaging requires vendor-authorised o3pack.exe. Supply -O3Pack <path>, or restore the upstream-tracked tool and runtime files at: $DefaultO3Pack"
    }
    if ((Split-Path -Leaf $O3Pack) -ine 'o3pack.exe') {
        throw "OSTC Companion packaging requires the vendor o3pack.exe executable, not: $O3Pack"
    }

    $O3PackDirectory = Split-Path -Parent $O3Pack
    foreach ($RuntimeFile in @('1.dll', 'QtCore4.dll', 'QtGui4.dll', 'QtSvg4.dll')) {
        if (-not (Test-Path -LiteralPath (Join-Path $O3PackDirectory $RuntimeFile) -PathType Leaf)) {
            throw "Required o3pack runtime file is missing beside ${O3Pack}: $RuntimeFile"
        }
    }

    Remove-Item -LiteralPath $Ostc3Package -Force -ErrorAction SilentlyContinue
    Write-Host ('PACKAGE {0}' -f $Ostc3Package)
    Push-Location -LiteralPath $O3PackDirectory
    try {
        Invoke-BuildTool -Tool $O3Pack -Arguments @('-ostc3', $FullHex, '-f', $Ostc3Package)
    } finally {
        Pop-Location
    }
    if (-not (Test-Path -LiteralPath $Ostc3Package -PathType Leaf) -or (Get-Item -LiteralPath $Ostc3Package).Length -eq 0) {
        throw "o3pack did not create an OSTC Companion package: $Ostc3Package"
    }

    $ContainerLines = @(Get-Content -LiteralPath $Ostc3Package -Encoding ascii)
    if ($ContainerLines.Count -ne 7682) {
        throw "o3pack output has $($ContainerLines.Count) records; expected 7682: $Ostc3Package"
    }
    for ($Index = 0; $Index -lt 7681; $Index++) {
        $Record = $ContainerLines[$Index]
        if ($Record -notmatch '^:[0-9A-Fa-f]{6}[0-9A-Fa-f]{32}$' -or [Convert]::ToInt32($Record.Substring(1, 6), 16) -ne ($Index * 16)) {
            throw "o3pack output has an invalid data record at index ${Index}: $Ostc3Package"
        }
    }
    if ($ContainerLines[7681] -notmatch '^:01[Ee]010[0-9A-Fa-f]{8}$') {
        throw "o3pack output has an invalid final record: $Ostc3Package"
    }

    $PackagingMetadata = @(
        "ostc3_package=$Ostc3Package"
        "ostc3_package_input_sha256=$FullHash"
        "ostc3_package_sha256=$((Get-FileHash -LiteralPath $Ostc3Package -Algorithm SHA256).Hash.ToLowerInvariant())"
        "o3pack_path=$O3Pack"
        "o3pack_sha256=$((Get-FileHash -LiteralPath $O3Pack -Algorithm SHA256).Hash.ToLowerInvariant())"
    )
}

$BuildInfo = Join-Path $BuildDir 'build-info.txt'
@(
    "source_commit=$SourceCommit"
    "source_branch=$SourceBranch"
    "source_changeset=$SourceChangeset"
    "processor=$Processor"
    "c18_root=$DetectedC18Root"
    "mcc18_sha256=$((Get-FileHash -LiteralPath $Mcc18 -Algorithm SHA256).Hash.ToLowerInvariant())"
    "mpasm_sha256=$((Get-FileHash -LiteralPath $Mpasm -Algorithm SHA256).Hash.ToLowerInvariant())"
    "mplink_sha256=$((Get-FileHash -LiteralPath $Mplink -Algorithm SHA256).Hash.ToLowerInvariant())"
    "srec_cat_sha256=$((Get-FileHash -LiteralPath $SrecCat -Algorithm SHA256).Hash.ToLowerInvariant())"
    "full_hex_sha256=$FullHash"
    "upload_hex_sha256=$TinyHash"
    "mcc18_banner=$Mcc18Banner"
    "mcc18_licensed_mode_guess=$($Mcc18LicensedModeGuess.ToString().ToLowerInvariant())"
    $MemoryBudgetMetadata
    $PackagingMetadata
) | Set-Content -LiteralPath $BuildInfo -Encoding ascii

Write-Host "`nUpload artefact: $TinyHex"
if ($DoPackageOstc3) {
    Write-Host "OSTC Companion package: $Ostc3Package"
}
Write-Host "Build metadata:  $BuildInfo"
