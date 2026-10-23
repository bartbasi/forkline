# Forkline. Copyright 2026 Play, Inc.
# Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.
#
# Builds the debug APK: build\forkline-debug.apk
#
# Run from any folder:
#   powershell -ExecutionPolicy Bypass -File scripts\build.ps1
#
# Godot 4.7.2 must be on PATH as "godot", or set the GODOT environment variable
# to the full path of the Godot exe. The Android SDK, the JDK and the debug
# keystore come from Godot's Editor Settings, never from this repo.

$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$Godot = if ($env:GODOT) { $env:GODOT } else { 'godot' }
$Apk = Join-Path $Root 'build\forkline-debug.apk'
$WantVersion = '4.7.2.stable'

# Godot is a window app. PowerShell only waits for it, and only sets
# $LASTEXITCODE, when its output is piped, so every Godot call is piped.
function Invoke-Godot {
    & $Godot @args | Out-Host
    return $LASTEXITCODE
}

if (-not (Get-Command $Godot -ErrorAction SilentlyContinue)) {
    Write-Host "Godot was not found as '$Godot'. Install Godot $WantVersion or set GODOT to the full path of its exe."
    exit 1
}

$Version = (& $Godot --version | Out-String).Trim()
if (-not $Version.StartsWith($WantVersion)) {
    Write-Host "This project needs Godot $WantVersion, but '$Godot' is version '$Version'."
    exit 1
}
Write-Host "Godot $Version"

Write-Host 'Importing the project...'
$Code = Invoke-Godot --headless --path $Root --import
if ($Code -ne 0) {
    Write-Host "The import failed with exit code $Code. Read the Godot output above."
    exit 1
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Apk) | Out-Null
if (Test-Path $Apk) {
    Remove-Item -Force $Apk
}

Write-Host 'Exporting the debug APK...'
$Code = Invoke-Godot --headless --path $Root --export-debug 'Android' $Apk
if ($Code -ne 0 -or -not (Test-Path $Apk)) {
    Write-Host "The export failed (exit code $Code). Read the Godot output above."
    exit 1
}

$SizeMb = [math]::Round((Get-Item $Apk).Length / 1MB, 1)
Write-Host "Built $Apk ($SizeMb MB)"
Write-Host 'Check it with: scripts/check_apk.sh (in Git Bash)'
Write-Host 'Install it with: powershell -ExecutionPolicy Bypass -File scripts\install.ps1'
exit 0
