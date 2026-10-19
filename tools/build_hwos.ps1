<#
.SYNOPSIS
Build the hwOS PIC18F87K22 firmware with the Windows MPLAB C18 toolchain.

.DESCRIPTION
Produces the same complete and TinyBld-cropped Intel HEX files as
build_hwos.sh. It compiles every top-level src/*.asm and src/*.c file with
MPLAB C18 v3.42 or newer, then crops the linked image to 0x00000..0x1DFFF.
The script never flashes or uploads firmware.
#>
[CmdletBinding()]
param(
    [string]$C18Root,
    [string]$Mcc18,
    [string]$Mpasm,
    [string]$Mplink,
    [string]$SrecCat,
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

    foreach ($CommandName in @($Name, "$Name.exe")) {
        $Command = Get-Command $CommandName -CommandType Application -ErrorAction SilentlyContinue
        if ($Command) {
            return $Command.Path
        }
    }

    throw "Required tool '$Name' was not found. Install official MPLAB C18 v3.47 and Windows SRecord, add them to PATH, or provide its explicit script parameter."
}

function Invoke-BuildTool {
    param(
        [string]$Tool,
        [string[]]$Arguments
    )

    & $Tool @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code $LASTEXITCODE: $Tool $($Arguments -join ' ')"
    }
}

$C18Roots = @()
if ($C18Root) {
    $C18Roots += $C18Root
}
if ($env:C18_ROOT) {
    $C18Roots += $env:C18_ROOT
}
foreach ($ProgramFiles in @([Environment]::GetFolderPath('ProgramFilesX86'), [Environment]::GetFolderPath('ProgramFiles'))) {
    if ($ProgramFiles) {
        $C18Roots += (Join-Path $ProgramFiles 'Microchip\mplabc18\v3.47')
    }
}
$C18Roots = $C18Roots | Select-Object -Unique

$Mcc18Candidates = @($C18Roots | ForEach-Object { Join-Path $_ 'bin\mcc18.exe' })
$MpasmCandidates = @($C18Roots | ForEach-Object { Join-Path $_ 'mpasm\mpasmx.exe' })
$MplinkCandidates = @($C18Roots | ForEach-Object { Join-Path $_ 'bin\mplink.exe' })

$Mcc18 = Resolve-BuildTool -Name 'mcc18' -ConfiguredPath $Mcc18 -Candidates $Mcc18Candidates
$Mpasm = Resolve-BuildTool -Name 'mpasmx' -ConfiguredPath $Mpasm -Candidates $MpasmCandidates
$Mplink = Resolve-BuildTool -Name 'mplink' -ConfiguredPath $Mplink -Candidates $MplinkCandidates
$SrecCat = Resolve-BuildTool -Name 'srec_cat' -ConfiguredPath $SrecCat

# The C18 standard headers are needed by p2_deco.c. Derive them from the
# selected compiler rather than relying on an installer-created MCC_INCLUDE.
$DetectedC18Root = Split-Path -Parent (Split-Path -Parent $Mcc18)
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

$Git = Get-Command git.exe -CommandType Application -ErrorAction SilentlyContinue
if (-not $Git) {
    $Git = Get-Command git -CommandType Application -ErrorAction SilentlyContinue
}
if (-not $Git) {
    throw 'Required tool git was not found on PATH. A Git checkout is required to record the source commit in build-info.txt.'
}

$SourceCommit = (& $Git.Path -C $RepoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or -not $SourceCommit) {
    throw "Unable to determine the source commit in $RepoRoot."
}

Remove-Item -LiteralPath $ObjectDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $ObjectDir -Force | Out-Null

$Objects = [System.Collections.Generic.List[string]]::new()
Get-ChildItem -LiteralPath $SourceDir -Filter '*.asm' -File | Sort-Object Name | ForEach-Object {
    $Object = Join-Path $ObjectDir ($_.BaseName + '.o')
    Write-Host ('ASM  src\{0}' -f $_.Name)
    Invoke-BuildTool -Tool $Mpasm -Arguments @('/q', "/p$Processor", "/o$Object", $_.FullName)
    $Objects.Add($Object)
}

Get-ChildItem -LiteralPath $SourceDir -Filter '*.c' -File | Sort-Object Name | ForEach-Object {
    $Object = Join-Path $ObjectDir ($_.BaseName + '.o')
    Write-Host ('C18  src\{0}' -f $_.Name)
    Invoke-BuildTool -Tool $Mcc18 -Arguments @("-p=$Processor", "-I$SourceDir", "-I$C18IncludeDir", "-fo=$Object", $_.FullName)
    $Objects.Add($Object)
}

$FullHex = Join-Path $BuildDir 'hwos.production.hex'
$TinyHex = Join-Path $BuildDir 'hwos_tiny.hex'
$MapFile = Join-Path $BuildDir 'hwos.map'
$LinkerScript = Join-Path $SourceDir '18F87K22_hwos.lkr'

Write-Host ('LINK {0}' -f $FullHex)
$LinkArguments = @("/p$Processor", '/w', "/m$MapFile", "/o$FullHex", "/l$LinkerScript")
$LinkArguments += $Objects.ToArray()
Invoke-BuildTool -Tool $Mplink -Arguments $LinkArguments

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
$BuildInfo = Join-Path $BuildDir 'build-info.txt'
@(
    "source_commit=$SourceCommit"
    "processor=$Processor"
    "full_hex_sha256=$FullHash"
    "upload_hex_sha256=$TinyHash"
) | Set-Content -LiteralPath $BuildInfo -Encoding ascii

Write-Host "`nUpload artefact: $TinyHex"
Write-Host "Build metadata:  $BuildInfo"
