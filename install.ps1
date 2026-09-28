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
    #
    # Read and written through the registry as the value is held, never
    # through [Environment]::GetEnvironmentVariable/SetEnvironmentVariable:
    # that pair expands every %VAR% on the read and writes REG_SZ, so a
    # round trip turned the user's references into fixed paths and the value
    # into a kind that expands nothing. The same statements as
    # OPEN_RAW_USER_PATH and WRITE_RAW_USER_PATH in the CLI's
    # agents/detection-probes.ts, which the CLI and the desktop both import;
    # a test holds this copy to them word for word.
    $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Environment')
    $hasPath = @($key.GetValueNames()) -contains 'Path'
    $kind = if ($hasPath) { $key.GetValueKind('Path') } else { [Microsoft.Win32.RegistryValueKind]::ExpandString }
    $raw = if ($hasPath) { [string]$key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames) } else { '' }
    # Entry-wise, case-insensitive, trailing-separator tolerant, each entry's
    # references expanded for the comparison only -- the same comparison the
    # desktop makes (cli-resolver.ts). An exact -contains here could not
    # recognise an entry the desktop had written, so the two writers appended
    # duplicates of each other's paths.
    $pathEntries = @($raw -split ';' | Where-Object { $_ -and $_.Trim() -ne '' })
    $normalizedTarget = $installDir.TrimEnd('\').ToLower()
    $alreadyOnPath = [bool]($pathEntries | Where-Object { [Environment]::ExpandEnvironmentVariables($_).TrimEnd('\').ToLower() -eq $normalizedTarget })

    if (-not $alreadyOnPath) {
        $trimmed = $raw.TrimEnd(';')
        $next = if ($trimmed) { "$trimmed;$installDir" } else { $installDir }
        $key.SetValue('Path', $next, $kind)
        # SetValue, unlike SetEnvironmentVariable, tells no running program;
        # without this a shell opened from Explorer keeps the old PATH. Best
        # effort: the value is written, and failing here must not fail the
        # install.
        try { Add-Type -Namespace RunworkEnvironment -Name Broadcast -MemberDefinition '[DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)] public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);'; $sent = [UIntPtr]::Zero; [void][RunworkEnvironment.Broadcast]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$sent) } catch { }
        Write-Info ''
        Write-Info "Added $installDir to your user PATH."
        Write-Info 'Open a new PowerShell window so the new PATH is visible to your shell.'
    }
    $key.Close()

    Write-Info ''
    Write-Info "Runwork CLI $version installed to $binaryDst"

    # Runwork's own git, which `runwork dev` and `runwork deploy` build with.
    # Installed now so the first command does not wait for it, and never
    # fatal: that first command installs it too. Runs the binary just
    # installed, not whichever runwork comes first on PATH. `--background`
    # because nobody asked for git by name: RUNWORK_GIT=system means leave this
    # machine on its own git. Start-Process with both streams in files, so the
    # CLI's JSON lines stay out of the output and its stderr cannot trip
    # $ErrorActionPreference = 'Stop' as a native command's stderr would.
    Write-Info ''
    Write-Info "Installing Runwork's git..."
    $gitOutLog = Join-Path $tmpDir 'git-install.log'
    $gitErrLog = Join-Path $tmpDir 'git-install.err'
    $gitResult = $null
    $gitReason = $null
    try {
        $gitProcess = Start-Process -FilePath $binaryDst -ArgumentList 'git', 'install', '--background', '--json' -NoNewWindow -Wait -PassThru -RedirectStandardOutput $gitOutLog -RedirectStandardError $gitErrLog
        # The CLI's last done, error or skipped line (commands/git.ts).
        foreach ($line in @(Get-Content -Path $gitOutLog -ErrorAction SilentlyContinue)) {
            if ($line -notmatch '^\s*\{') { continue }
            try {
                $parsed = $line | ConvertFrom-Json
            } catch {
                continue
            }
            if (@('done', 'error', 'skipped') -contains $parsed.kind) { $gitResult = $parsed }
        }
        if (-not $gitResult) {
            # An older CLI without `runwork git` says "unknown command".
            $gitReason = @(@(Get-Content -Path $gitErrLog -ErrorAction SilentlyContinue) + @(Get-Content -Path $gitOutLog -ErrorAction SilentlyContinue) | Where-Object { $_ -and $_.Trim() }) | Select-Object -Last 1
            if (-not $gitReason) { $gitReason = "exit code $($gitProcess.ExitCode)" }
        }
    } catch {
        $gitReason = $_.Exception.Message
    }
    if ($gitResult -and $gitResult.kind -eq 'done') {
        Write-Info "  Ready in $($gitResult.path)"
    } elseif ($gitResult -and $gitResult.kind -eq 'skipped') {
        Write-Info "  Skipped: $($gitResult.reason)"
    } else {
        if ($gitResult) { $gitReason = $gitResult.message }
        Write-Info "  Could not install it now ($("$gitReason".TrimEnd('.'))). Runwork will try again when a command needs git."
    }

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
