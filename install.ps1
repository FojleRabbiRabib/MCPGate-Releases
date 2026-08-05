# install.ps1 — Native PowerShell installer for MCPGate on Windows
#
# Downloads the latest MCPGate release, verifies SHA256 and ed25519 signature,
# extracts mcpgate.exe, installs to %LOCALAPPDATA%\Programs\MCPGate\, and
# optionally adds that directory to the user PATH.
#
# Usage (run in an ordinary PowerShell prompt — no elevation needed):
#   irm https://raw.githubusercontent.com/FojleRabbiRabib/MCPGate-Releases/main/install.ps1 | iex
#
# Or with options:
#   $env:VERSION = "v1.2.3"                         # pin a specific release
#   $env:INSTALL_DIR = "C:\tools\mcpgate"           # override install path
#   iex (irm https://...install.ps1)
#
# For an automated / non-interactive install (skips PATH prompt):
#   & { $env:SKIP_PATH_PROMPT = "1"; iex (irm https://...install.ps1) }
#
# To register mcpgate as a Windows Service after install (requires an
# elevated/Administrator prompt):
#   mcpgate service install
#   mcpgate service start
#
#Requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Configuration ──────────────────────────────────────────────────────────────
$ReleasesRepo  = 'FojleRabbiRabib/MCPGate-Releases'
$InstallDir    = if ($env:INSTALL_DIR) { $env:INSTALL_DIR } `
                 else { Join-Path $env:LOCALAPPDATA 'Programs\MCPGate' }
$Version       = $env:VERSION   # empty = fetch latest
$SkipPathPrompt = ($env:SKIP_PATH_PROMPT -eq '1')

# Embedded ed25519 public key (PEM). The corresponding private key is kept
# offline. A valid signature binds the archive to the maintainer's key.
$SigningPubKeyPem = @'
-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEATLE/mKPX5XUUhOh6XN6T0XOvn2zKGyte4YyMFEa9bHk=
-----END PUBLIC KEY-----
'@

# ── Helper: write a status line ────────────────────────────────────────────────
function Write-Step([string]$msg) { Write-Host $msg -ForegroundColor Cyan }
function Write-Ok([string]$msg)   { Write-Host "✓ $msg" -ForegroundColor Green }
function Write-Warn([string]$msg) { Write-Host "⚠ $msg" -ForegroundColor Yellow }
function Fail([string]$msg) {
    Write-Host "✗ $msg" -ForegroundColor Red
    exit 1
}

# ── Dependency: openssl.exe ────────────────────────────────────────────────────
# openssl is required for ed25519 signature verification.
if (-not (Get-Command openssl.exe -ErrorAction SilentlyContinue)) {
    Fail 'openssl.exe is required for release-signature verification. Install Git for Windows and retry.'
}

# ── Architecture detection ─────────────────────────────────────────────────────
$arch = switch ($env:PROCESSOR_ARCHITECTURE) {
    'AMD64' { 'amd64' }
    'ARM64' { 'arm64' }
    default  { Fail "Unsupported architecture: $env:PROCESSOR_ARCHITECTURE" }
}

# ── Version resolution ─────────────────────────────────────────────────────────
if (-not $Version) {
    Write-Step 'Fetching latest release version…'
    try {
        $rel = Invoke-RestMethod "https://api.github.com/repos/$ReleasesRepo/releases/latest" `
            -Headers @{ 'User-Agent' = 'mcpgate-installer/1.0' }
        $Version = $rel.tag_name
    } catch {
        Fail "Could not fetch latest release: $_`nSet `$env:VERSION = 'vX.Y.Z' and retry."
    }
}
if (-not $Version -or $Version -eq 'null') {
    Fail "Version is empty. Set `$env:VERSION = 'vX.Y.Z' explicitly and retry."
}

Write-Host "Installing MCPGate $Version for windows/$arch…" -ForegroundColor White

# ── Download URLs ──────────────────────────────────────────────────────────────
$archiveName   = "mcpgate_${Version}_windows_${arch}.zip"
$baseUrl       = "https://github.com/$ReleasesRepo/releases/download/$Version"
$archiveUrl    = "$baseUrl/$archiveName"
$checksumUrl   = "$baseUrl/checksums.txt"
$signatureUrl  = "$baseUrl/${archiveName}.sig"

# ── Temp workspace ─────────────────────────────────────────────────────────────
$tmp = Join-Path $env:TEMP "mcpgate-install-$([System.IO.Path]::GetRandomFileName())"
New-Item -ItemType Directory -Path $tmp | Out-Null
try {

# ── Download archive ───────────────────────────────────────────────────────────
Write-Step "Downloading $archiveName…"
$archivePath = Join-Path $tmp $archiveName
try {
    Invoke-WebRequest $archiveUrl -OutFile $archivePath -UseBasicParsing
} catch {
    Fail "Download failed: $_`nURL: $archiveUrl"
}

# ── SHA256 verification ────────────────────────────────────────────────────────
Write-Step 'Verifying SHA256…'
$checksumPath = Join-Path $tmp 'checksums.txt'
try {
    Invoke-WebRequest $checksumUrl -OutFile $checksumPath -UseBasicParsing
} catch {
    Fail "Failed to download checksums.txt: $_"
}

# Parse sha256sum format: "<hex>  <filename>" — find our archive's line.
$expectedHash = $null
foreach ($line in (Get-Content $checksumPath)) {
    $parts = $line -split '\s+', 2
    if ($parts.Count -eq 2) {
        # Strip a leading '*' that some tools emit before the filename.
        $fname = $parts[1].TrimStart('*').Trim()
        if ($fname -eq $archiveName) {
            $expectedHash = $parts[0].Trim().ToLower()
            break
        }
    }
}
if (-not $expectedHash) {
    Fail "checksums.txt has no entry for $archiveName.`nContents:`n$(Get-Content $checksumPath | Out-String)"
}

$actualHash = (Get-FileHash $archivePath -Algorithm SHA256).Hash.ToLower()
if ($actualHash -ne $expectedHash) {
    Fail "SHA256 mismatch!`n  expected: $expectedHash`n  actual:   $actualHash"
}
Write-Ok 'SHA256 OK'

# ── Ed25519 signature verification ────────────────────────────────────────────
Write-Step 'Verifying ed25519 signature…'
$sigPath    = Join-Path $tmp "${archiveName}.sig"
$pubkeyPath = Join-Path $tmp 'signing.pub'

try {
    Invoke-WebRequest $signatureUrl -OutFile $sigPath -UseBasicParsing
} catch {
    Fail "Release $Version is missing ${archiveName}.sig.`nUnsigned releases are refused. A newly published release may not be signed yet — retry later, or pin a previous VERSION."
}

Set-Content -Path $pubkeyPath -Value $SigningPubKeyPem -Encoding ASCII
$result = & openssl.exe pkeyutl -verify -pubin -inkey $pubkeyPath `
    -rawin -in $archivePath -sigfile $sigPath 2>&1
if ($LASTEXITCODE -ne 0) {
    Fail "Ed25519 signature did NOT verify against the maintainer's key.`nThis is a hard refusal — the downloaded archive is not trusted.`nopenssl output: $result"
}
Write-Ok 'Signature OK'

# ── Extract mcpgate.exe ────────────────────────────────────────────────────────
Write-Step 'Extracting mcpgate.exe…'
$extractDir = Join-Path $tmp 'unpack'
Expand-Archive -Path $archivePath -DestinationPath $extractDir -Force

# The binary may be nested one directory deep inside the archive.
$exeFile = Get-ChildItem -Path $extractDir -Filter 'mcpgate.exe' -Recurse -File |
    Select-Object -First 1
if (-not $exeFile) {
    Fail "mcpgate.exe not found inside $archiveName after extraction.`nContents: $(Get-ChildItem $extractDir -Recurse | Select-Object -ExpandProperty FullName | Out-String)"
}

# ── Install ────────────────────────────────────────────────────────────────────
Write-Step "Installing to $InstallDir…"
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir | Out-Null
}
$destExe = Join-Path $InstallDir 'mcpgate.exe'
Copy-Item -Path $exeFile.FullName -Destination $destExe -Force
Write-Ok "MCPGate $Version installed → $destExe"

# ── User PATH update ───────────────────────────────────────────────────────────
$userPath = [System.Environment]::GetEnvironmentVariable('PATH', 'User')
$pathDirs = $userPath -split ';' | Where-Object { $_ -ne '' }

if ($pathDirs -notcontains $InstallDir) {
    if ($SkipPathPrompt) {
        $addToPath = 'y'
    } else {
        Write-Host ''
        Write-Warn "$InstallDir is not in your user PATH."
        $addToPath = Read-Host "Add it now? [Y/n]"
        if (-not $addToPath) { $addToPath = 'y' }
    }

    if ($addToPath -match '^[Yy]') {
        $newPath = ($pathDirs + $InstallDir) -join ';'
        [System.Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')
        # Also update the current session so mcpgate is immediately usable.
        $env:PATH = "$env:PATH;$InstallDir"
        Write-Ok "$InstallDir added to user PATH (takes effect in new terminals)"
    } else {
        Write-Warn "PATH not updated. Add '$InstallDir' to your PATH manually to use mcpgate from any prompt."
    }
} else {
    Write-Ok "$InstallDir is already in your PATH"
}

# ── Next steps ─────────────────────────────────────────────────────────────────
Write-Host ''
Write-Host 'Next steps:' -ForegroundColor White
Write-Host '  Register mcpgate as a Windows Service (requires an Administrator prompt):'
Write-Host '    mcpgate service install   # auto-start on boot, restart on failure'
Write-Host '    mcpgate service start     # start it now'
Write-Host ''
Write-Host "  Verify it's running:"
Write-Host '    mcpgate service status'
Write-Host ''
Write-Host "Run 'mcpgate --help' to get started." -ForegroundColor White

} finally {
    # Always clean up the temp directory.
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
