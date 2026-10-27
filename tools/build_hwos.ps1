<#
.SYNOPSIS
Build the hwOS PIC18F87K22 firmware with the Windows MPLAB C18 toolchain.

.DESCRIPTION
Compiles every top-level src/*.asm and src/*.c file with the vendor's MPLAB
C18 v3.42 environment, then crops the linked image to 0x00000..0x1DFFF.
Unless -BuildOnly is given, it then invokes a local or explicitly supplied
vendor-authorised o3pack.exe to make an UNVALIDATED OSTC Companion container.
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
    [string]$BuildDir = 'build'
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
    $Ostc3Package = "hwos_ostc3_${SafeSourceBranch}_${SourceChangeset}_UNVALIDATED_firmware.hex"
}
if ([System.IO.Path]::IsPathRooted($Ostc3Package)) {
    $Ostc3Package = [System.IO.Path]::GetFullPath($Ostc3Package)
} else {
    $Ostc3Package = Join-Path $BuildDir $Ostc3Package
}
if ($DoPackageOstc3 -and ((Split-Path -Leaf $Ostc3Package) -notmatch 'UNVALIDATED')) {
    throw "OSTC Companion package filenames must contain 'UNVALIDATED': $Ostc3Package"
}

Remove-Item -LiteralPath $ObjectDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $ObjectDir -Force | Out-Null

$Objects = [System.Collections.Generic.List[string]]::new()
Get-ChildItem -LiteralPath $SourceDir -Filter '*.asm' -File | Sort-Object Name | ForEach-Object {
    $Object = Join-Path $ObjectDir ($_.BaseName + '.o')
    Write-Host ('ASM  src\{0}' -f $_.Name)
    Push-Location -LiteralPath $SourceDir
    try {
        Invoke-BuildTool -Tool $Mpasm -Arguments @('/q', "/p$Processor", "/o$Object", "/e$ObjectDir\$($_.BaseName).err", "/l$ObjectDir\$($_.BaseName).lst", $_.Name)
    } finally {
        Pop-Location
    }
    $Objects.Add($Object)
}

Get-ChildItem -LiteralPath $SourceDir -Filter '*.c' -File | Sort-Object Name | ForEach-Object {
    $Object = Join-Path $ObjectDir ($_.BaseName + '.o')
    Write-Host ('C18  src\{0}' -f $_.Name)
    Invoke-BuildTool -Tool $Mcc18 -Arguments @("-p=$Processor", "-I=$SourceDir", "-I=$C18IncludeDir", "-fo=$Object", "-fe=$ObjectDir\$($_.BaseName).err", $_.FullName)
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
    $PackagingMetadata
) | Set-Content -LiteralPath $BuildInfo -Encoding ascii

Write-Host "`nUpload artefact: $TinyHex"
if ($DoPackageOstc3) {
    Write-Host "UNVALIDATED OSTC Companion package: $Ostc3Package"
}
Write-Host "Build metadata:  $BuildInfo"
