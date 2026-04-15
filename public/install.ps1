# Plext CLI installer for Windows.
#
#   irm https://get.plext.com/install.ps1 | iex
#
# Environment overrides (all optional):
#   $env:PLEXT_VERSION   pin to a specific tag (e.g. v0.1.0). Defaults to latest.
#   $env:PLEXT_INSTALL   install directory. Defaults to $env:LOCALAPPDATA\Plext\bin.
#   $env:PLEXT_DL_BASE   download base URL. Defaults to https://dl.plext.com.
#   $env:PLEXT_NO_PATH   skip User PATH modification.
#
# This script is public and auditable. Read it before piping into iex.

$ErrorActionPreference = 'Stop'

function Write-Info($msg) { Write-Host "  $msg" }
function Write-Ok($msg)   { Write-Host "  " -NoNewline; Write-Host -Foreground Green "OK " -NoNewline; Write-Host $msg }
function Write-Warn($msg) { Write-Host "  " -NoNewline; Write-Host -Foreground Yellow "!  " -NoNewline; Write-Host $msg }
function Fail($msg)       { Write-Host "  " -NoNewline; Write-Host -Foreground Red "x  " -NoNewline; Write-Host $msg; exit 1 }

# Arch check — we ship amd64 only today.
$arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
if ($arch -ne 'X64') {
    Fail "Plext currently ships Windows builds for x64 only. Detected: $arch"
}

$DlBase     = if ($env:PLEXT_DL_BASE)   { $env:PLEXT_DL_BASE }   else { 'https://dl.plext.com' }
$InstallDir = if ($env:PLEXT_INSTALL)   { $env:PLEXT_INSTALL }   else { Join-Path $env:LOCALAPPDATA 'Plext\bin' }

# Resolve version.
$Version = $env:PLEXT_VERSION
if (-not $Version) {
    try {
        $Version = (Invoke-WebRequest -UseBasicParsing -Uri "$DlBase/latest/version.txt").Content.Trim()
    } catch {
        Fail "Could not resolve latest version from $DlBase/latest/version.txt"
    }
}

Write-Host
Write-Host "Installing plext $Version for windows/amd64..."
Write-Host

$Archive       = "plext-windows-amd64.zip"
$ArchiveUrl    = "$DlBase/$Version/$Archive"
$ChecksumsUrl  = "$DlBase/$Version/checksums.txt"

$Tmp = Join-Path $env:TEMP ([System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path $Tmp | Out-Null

try {
    $ArchivePath   = Join-Path $Tmp $Archive
    $ChecksumsPath = Join-Path $Tmp 'checksums.txt'

    Write-Info "Downloading $ArchiveUrl"
    Invoke-WebRequest -UseBasicParsing -Uri $ArchiveUrl -OutFile $ArchivePath

    Write-Info "Downloading checksums.txt"
    Invoke-WebRequest -UseBasicParsing -Uri $ChecksumsUrl -OutFile $ChecksumsPath

    # Verify SHA256 — match against the checksums.txt line for this archive.
    $ExpectedLine = Get-Content $ChecksumsPath | Where-Object { $_ -match "\s+$Archive$" } | Select-Object -First 1
    if (-not $ExpectedLine) {
        Fail "No checksum entry for $Archive in checksums.txt"
    }
    $Expected = ($ExpectedLine -split '\s+')[0]
    $Actual   = (Get-FileHash -Algorithm SHA256 -Path $ArchivePath).Hash.ToLower()
    if ($Expected.ToLower() -ne $Actual) {
        Fail "Checksum mismatch: expected $Expected, got $Actual"
    }
    Write-Ok "Checksum verified"

    # Extract.
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    $ExtractDir = Join-Path $Tmp 'extract'
    New-Item -ItemType Directory -Path $ExtractDir | Out-Null
    Expand-Archive -Path $ArchivePath -DestinationPath $ExtractDir -Force

    $ExtractedBin = Join-Path $ExtractDir 'plext-windows-amd64.exe'
    if (-not (Test-Path $ExtractedBin)) {
        Fail "Archive did not contain plext-windows-amd64.exe"
    }

    $FinalBin = Join-Path $InstallDir 'plext.exe'
    Copy-Item -Path $ExtractedBin -Destination $FinalBin -Force
    Write-Ok "Installed to $FinalBin"

    # Add to User PATH via registry (no admin required, persists).
    if (-not $env:PLEXT_NO_PATH) {
        $UserPath = [Environment]::GetEnvironmentVariable('Path', 'User')
        if (-not $UserPath) { $UserPath = '' }
        $PathParts = $UserPath -split ';' | Where-Object { $_ -ne '' }
        if ($PathParts -notcontains $InstallDir) {
            $NewPath = ($PathParts + $InstallDir) -join ';'
            [Environment]::SetEnvironmentVariable('Path', $NewPath, 'User')
            Write-Ok "Added $InstallDir to your User PATH"
            Write-Warn "Restart your terminal for the PATH change to take effect."
        }
    }

    # Warnings for known friction points.
    if (-not (Get-Command sh.exe -ErrorAction SilentlyContinue)) {
        Write-Warn "sh.exe not found. Install Git for Windows (https://git-scm.com/download/win) — some plext features expect a POSIX shell."
    }

    Write-Host
    Write-Ok "plext $Version installed"
    Write-Host
    Write-Info "Next steps:"
    Write-Info "  1. Open a new terminal so the PATH change takes effect"
    Write-Info "  2. Run: plext --help"
    Write-Info "  3. Get started: plext setup"
    Write-Host
    Write-Warn "First run may trigger Windows SmartScreen (unsigned binary)."
    Write-Warn "Click 'More info' -> 'Run anyway' to proceed. We're working on code signing."
    Write-Host
}
finally {
    Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
}
