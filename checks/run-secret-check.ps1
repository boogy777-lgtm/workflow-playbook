# run-secret-check.ps1  (Windows PowerShell)
# Universal pre-publish secret scanner. Cross-platform twin of run-secret-check.sh.
# Ensures the Betterleaks scanner is present and at the latest stable release,
# installing or updating it automatically, then scans a target folder: working
# tree plus full git history, using Betterleaks' built-in rules plus any
# project-specific rules in betterleaks-extra.toml.
# Exits 0 when clean, nonzero when anything is found, so it can gate a publish step.
# No scanner binary is committed to any repo; this script fetches it on demand.
#
# Usage:
#   .\run-secret-check.ps1                          # scan current folder
#   .\run-secret-check.ps1 -Target C:\path\to\repo  # scan a specific folder

param([string]$Target = ".")
$ErrorActionPreference = "Stop"
if (-not (Test-Path -LiteralPath $Target -PathType Container)) {
    Write-Host "ERROR: target is not an existing directory: $Target" -ForegroundColor Red
    exit 2
}

$LocalDir = Join-Path $env:LOCALAPPDATA "betterleaks"

function Get-LatestStable {
    # The /releases/latest endpoint returns the newest non-prerelease: latest stable.
    try {
        $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/betterleaks/betterleaks/releases/latest" `
               -Headers @{ "User-Agent" = "run-secret-check" } -TimeoutSec 20
        $archAlt = if ($env:PROCESSOR_ARCHITECTURE -match "ARM") { "arm64|arm" } else { "amd64|x64|86_64" }
        $asset = $rel.assets | Where-Object { $_.name -match "windows.*($archAlt)" } | Select-Object -First 1
        return [pscustomobject]@{ Version = ($rel.tag_name -replace "^v", ""); Url = $asset.browser_download_url }
    } catch { return $null }
}

function Get-BinVersion {
    param([string]$Bin)
    try {
        $out = (& $Bin --version 2>&1) -join " "
        if ($out -match "(\d+\.\d+\.\d+)") { return $Matches[1] }
    } catch { }
    return $null
}

function Install-ToLocalDir {
    param($Release)
    if (-not $Release.Url) { return $null }
    New-Item -ItemType Directory -Force -Path $LocalDir | Out-Null
    $zip = Join-Path $env:TEMP "betterleaks-latest.zip"
    Invoke-WebRequest -Uri $Release.Url -OutFile $zip -UseBasicParsing -TimeoutSec 300
    Expand-Archive -Path $zip -DestinationPath $LocalDir -Force
    Remove-Item $zip -ErrorAction SilentlyContinue
    $exe = Join-Path $LocalDir "betterleaks.exe"
    if (Test-Path $exe) { return $exe } else { return $null }
}

function Resolve-Bin {
    if (Get-Command betterleaks -ErrorAction SilentlyContinue) { return (Get-Command betterleaks).Source }
    $local = Join-Path $LocalDir "betterleaks.exe"
    if (Test-Path $local) { return $local }
    return $null
}

function Merge-Configs {
    # Betterleaks honours only the LAST --config flag: stacked flags silently
    # disable the earlier files. Merge every existing config into one temp
    # file instead: concatenate, keep exactly one [extend] useDefault=true
    # block, drop any other title line. Returns $null when no config exists.
    param([string[]]$Paths)
    $existing = @($Paths | Where-Object { $_ -and (Test-Path $_) })
    if ($existing.Count -eq 0) { return $null }
    $out = Join-Path $env:TEMP ("betterleaks-merged-" + [guid]::NewGuid().ToString("N") + ".toml")
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("[extend]")
    $lines.Add("useDefault = true")
    foreach ($p in $existing) {
        $inExtend = $false
        $first = $true
        foreach ($line in (Get-Content -LiteralPath $p)) {
            if ($first) { $line = $line.TrimStart([char]0xFEFF); $first = $false }   # strip BOM
            $t = $line.Trim()
            if ($t -match '^\[extend\]$') { $inExtend = $true; continue }
            if ($inExtend -and $t -match '^\[') { $inExtend = $false }
            if ($inExtend) { continue }
            if ($t -match '^title\s*=') { continue }
            $lines.Add($line)
        }
    }
    # Write WITHOUT a BOM: Windows PowerShell's Set-Content -Encoding UTF8 emits
    # one, and Betterleaks' TOML parser dies on it ("invalid character at start of key").
    [System.IO.File]::WriteAllLines($out, $lines, (New-Object System.Text.UTF8Encoding($false)))
    return $out
}

# --- Install if missing -------------------------------------------------------
$Bin = Resolve-Bin
if (-not $Bin) {
    Write-Host "betterleaks not found; installing the latest stable release..." -ForegroundColor Cyan
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install -e --id Betterleaks.Betterleaks --accept-source-agreements --accept-package-agreements | Out-Null
        $env:Path += ";$env:LOCALAPPDATA\Microsoft\WinGet\Links"
    }
    $Bin = Resolve-Bin
    if (-not $Bin) {
        $rel = Get-LatestStable
        if ($rel) { $Bin = Install-ToLocalDir $rel }
    }
    if (-not $Bin -or -not (Test-Path $Bin)) {
        Write-Host "ERROR: could not install betterleaks automatically." -ForegroundColor Red
        Write-Host "Install it from https://github.com/betterleaks/betterleaks/releases and re-run." -ForegroundColor Yellow
        exit 2
    }
}

# --- Update to latest stable ----------------------------------------------------
$have = Get-BinVersion $Bin
$rel  = Get-LatestStable
if ($rel -and $have) {
    $needUpdate = $false
    try { $needUpdate = ([version]$rel.Version -gt [version]$have) } catch { $needUpdate = ($rel.Version -ne $have) }
    if ($needUpdate) {
        Write-Host "betterleaks $have installed; updating to latest stable ($($rel.Version))..." -ForegroundColor Cyan
        $updated = $false
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            winget upgrade -e --id Betterleaks.Betterleaks --accept-source-agreements --accept-package-agreements | Out-Null
            $env:Path += ";$env:LOCALAPPDATA\Microsoft\WinGet\Links"
            $resolved = Resolve-Bin
            if ($resolved -and ((Get-BinVersion $resolved) -eq $rel.Version)) { $Bin = $resolved; $updated = $true }
        }
        if (-not $updated) {
            $dl = Install-ToLocalDir $rel
            if ($dl -and ((Get-BinVersion $dl) -eq $rel.Version)) { $Bin = $dl; $updated = $true }
        }
        if (-not $updated) { Write-Host "WARNING: update did not complete; scanning with $have." -ForegroundColor Yellow }
    }
} elseif (-not $rel) {
    Write-Host "WARNING: could not reach GitHub to check for a newer stable release; scanning with $have." -ForegroundColor Yellow
}

# --- Scan ------------------------------------------------------------------------
$scriptDir      = Split-Path -Parent $MyInvocation.MyCommand.Path
$extraConfig    = Join-Path $scriptDir "betterleaks-extra.toml"
$privateConfig  = Join-Path $scriptDir "scan-private.toml"   # untracked; holds personal identifiers
$merged         = Merge-Configs @($extraConfig, $privateConfig)
if ($merged) {
    if (Test-Path $privateConfig) { Write-Host "Including private rules from $privateConfig (kept out of git)." -ForegroundColor DarkGray }
    $configArgs = @("--config", $merged)
} else {
    $configArgs = @()
}

Write-Host "Scanning '$Target' for secrets (working tree + git history)..." -ForegroundColor Cyan

# Betterleaks logs to stderr; Windows PowerShell turns stderr into terminating
# errors under $ErrorActionPreference = Stop. Relax it for the scan only: the
# scan's exit code is the gate, not its log lines.
$previousPreference = $ErrorActionPreference
$code = 2
try {
    $ErrorActionPreference = "Continue"
    # Git history alone misses untracked and uncommitted work. Scan both inputs.
    # Redact matches so failed scans do not expose credentials in CI/chat logs.
    & $Bin dir @configArgs --no-banner --redact=100 --exit-code 1 "$Target"
    $code = $LASTEXITCODE
    $isGitRepo = & git -C $Target rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -eq 0) {
        & $Bin git @configArgs --log-opts=--all --no-banner --redact=100 --exit-code 1 "$Target"
        $historyCode = $LASTEXITCODE
        if ($historyCode -ne 0 -and ($code -eq 0 -or $historyCode -ne 1)) {
            $code = $historyCode
        }
    }
} finally {
    $ErrorActionPreference = $previousPreference
    if ($merged) { Remove-Item -LiteralPath $merged -ErrorAction SilentlyContinue }
}

if ($code -eq 0) {
    Write-Host ""
    Write-Host "CLEAN: no secrets detected." -ForegroundColor Green
} elseif ($code -eq 1) {
    Write-Host ""
    Write-Host "FOUND SECRETS. Do not publish until every hit above is reviewed." -ForegroundColor Red
    Write-Host "For each hit: confirm whether it is real. Rotate the credential if it was ever exposed," -ForegroundColor Yellow
    Write-Host "then remove it from the file AND from git history (git filter-repo / BFG)." -ForegroundColor Yellow
} else {
    Write-Host "ERROR: secret scan did not complete successfully (exit $code). Do not publish." -ForegroundColor Red
}
exit $code

