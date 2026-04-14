# Runwork CLI installer for Windows (PowerShell 5.1+)
# Usage:
#   irm https://runwork.ai/install.ps1 | iex
#
# Environment overrides:
#   RUNWORK_VERSION              Install a specific version (default: latest from manifest)
#   RUNWORK_INSTALL_DIR          Directory to install the binary (default: $env:USERPROFILE\.runwork\bin)
#   RUNWORK_DOWNLOAD_BASE_URL    Base URL to resolve manifest and artifacts (default: https://runwork.ai)

$ErrorActionPreference = 'Stop'

$BaseUrl = if ($env:RUNWORK_DOWNLOAD_BASE_URL) { $env:RUNWORK_DOWNLOAD_BASE_URL } else { 'https://runwork.ai' }
$BinaryName = 'runwork.exe'

function Write-Info([string]$Message) {
    Write-Host $Message
}

function Write-Err([string]$Message) {
    Write-Host "Error: $Message" -ForegroundColor Red
}

# Architecture detection
switch ($env:PROCESSOR_ARCHITECTURE) {
    'AMD64' { $arch = 'x64' }
    'ARM64' { $arch = 'arm64' }
    default {
        Write-Err "Unsupported architecture: $($env:PROCESSOR_ARCHITECTURE)"
        exit 1
    }
}

# Only x64 is currently published for Windows
if ($arch -ne 'x64') {
    Write-Err "Runwork CLI for Windows is only published for x64 at the moment."
    Write-Err "Track ARM64 support on https://runwork.ai/docs/cli."
    exit 1
}

$platform = "windows-$arch"

Write-Info "Fetching Runwork CLI release manifest from $BaseUrl/cli/latest.json..."
try {
    $manifest = Invoke-RestMethod -Uri "$BaseUrl/cli/latest.json" -Method Get -UseBasicParsing
} catch {
    Write-Err "failed to fetch release manifest from $BaseUrl/cli/latest.json"
    Write-Err "Check your network and that $BaseUrl is reachable."
    Write-Err "Underlying error: $($_.Exception.Message)"
    exit 1
}

# Artifact lookup
$artifactEntry = $null
if ($manifest.artifacts -and $manifest.artifacts.PSObject.Properties.Name -contains $platform) {
    $artifactEntry = $manifest.artifacts.$platform
}
if (-not $artifactEntry) {
    Write-Err "no artifact entry for platform '$platform' in the release manifest"
    Write-Err "The platform may not be published yet."
    exit 1
}

$artifactPath = $artifactEntry.path
$expectedSha = $artifactEntry.sha256

# Version resolution
$manifestVersion = $manifest.version
if (-not $manifestVersion) {
    Write-Err "could not determine version from manifest"
    exit 1
}

if ($env:RUNWORK_VERSION -and $env:RUNWORK_VERSION -ne $manifestVersion) {
    $version = $env:RUNWORK_VERSION
    $artifactFile = [System.IO.Path]::GetFileName($artifactPath)
    $artifactPath = "/cli/releases/$version/$artifactFile"

    Write-Info "Fetching checksums for pinned version $version..."
    try {
        $checksumsText = Invoke-RestMethod -Uri "$BaseUrl/cli/checksums/$version.txt" -Method Get -UseBasicParsing
    } catch {
        Write-Err "failed to fetch $BaseUrl/cli/checksums/$version.txt"
        Write-Err "Version $version may not exist."
        exit 1
    }

    $expectedSha = $null
    foreach ($line in ($checksumsText -split "`n")) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^([a-fA-F0-9]+)\s+(\S+)$') {
            if ($Matches[2] -eq $artifactFile) {
                $expectedSha = $Matches[1]
                break
            }
        }
    }
    if (-not $expectedSha) {
        Write-Err "no checksum found for $artifactFile in $BaseUrl/cli/checksums/$version.txt"
        exit 1
    }
} else {
    $version = $manifestVersion
}

$downloadUrl = "$BaseUrl$artifactPath"

Write-Info "Installing Runwork CLI $version ($platform)..."
Write-Info "  Downloading $downloadUrl"

$tmpDir = Join-Path $env:TEMP ("runwork-install-" + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

try {
    $archiveName = [System.IO.Path]::GetFileName($artifactPath)
    $archivePath = Join-Path $tmpDir $archiveName

    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $archivePath -UseBasicParsing
    } catch {
        Write-Err "failed to download $downloadUrl"
        Write-Err "Underlying error: $($_.Exception.Message)"
        exit 1
    }

    Write-Info "  Verifying sha256..."
    $actualSha = (Get-FileHash -Path $archivePath -Algorithm SHA256).Hash.ToLower()
    $expectedShaLower = $expectedSha.ToLower()
    if ($actualSha -ne $expectedShaLower) {
        Write-Err "sha256 mismatch for $archiveName"
        Write-Err "  expected: $expectedShaLower"
        Write-Err "  actual:   $actualSha"
        Write-Err "The download may be corrupted or tampered with. Re-run or file an issue."
        exit 1
    }

    Write-Info "  Extracting..."
    Expand-Archive -Path $archivePath -DestinationPath $tmpDir -Force

    # The archive contains a single executable named runwork-windows-x64.exe (or similar).
    $extractedExe = Get-ChildItem -Path $tmpDir -Filter 'runwork-*.exe' -File | Select-Object -First 1
    if (-not $extractedExe) {
        Write-Err "could not locate the runwork executable inside $archiveName"
        exit 1
    }

    $installDir = if ($env:RUNWORK_INSTALL_DIR) {
        $env:RUNWORK_INSTALL_DIR
    } else {
        Join-Path $env:USERPROFILE '.runwork\bin'
    }
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null

    $binaryDst = Join-Path $installDir $BinaryName
    Write-Info "  Installing to $binaryDst"

    if (Test-Path $binaryDst) {
        try {
            Remove-Item $binaryDst -Force
        } catch {
            Write-Err "could not replace existing ${binaryDst}: $($_.Exception.Message)"
            Write-Err "Close any running 'runwork' processes and re-run this installer."
            exit 1
        }
    }
    Move-Item -Path $extractedExe.FullName -Destination $binaryDst

    # Add install directory to user PATH if not already present.
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not $userPath) { $userPath = '' }
    $pathEntries = @($userPath -split ';' | Where-Object { $_ -and $_.Trim() -ne '' })
    $alreadyOnPath = $pathEntries -contains $installDir

    if (-not $alreadyOnPath) {
        $trimmedUserPath = $userPath.TrimEnd(';')
        $newUserPath = if ($trimmedUserPath) { "$trimmedUserPath;$installDir" } else { $installDir }
        [Environment]::SetEnvironmentVariable('Path', $newUserPath, 'User')
        Write-Info ''
        Write-Info "Added $installDir to your user PATH."
        Write-Info 'Open a new PowerShell window so the new PATH is visible to your shell.'
    }

    Write-Info ''
    Write-Info "Runwork CLI $version installed to $binaryDst"
    Write-Info ''
    Write-Info 'Get started:'
    Write-Info '  runwork login'
    Write-Info '  runwork init'
}
finally {
    if (Test-Path $tmpDir) {
        Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
