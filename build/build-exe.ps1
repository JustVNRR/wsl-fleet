[CmdletBinding()]
param (
    [string]$SourcePath = "launcher.cs",
    [string]$OutputExe  = "",
    [string]$IconPath   = "..\assets\app.ico"
)

$ErrorActionPreference = "Stop"

# 1. The source, beside this script by default; the exe, at the repository
# root by default - beside the entry it launches.
$resolvedSource = Join-Path $PSScriptRoot $SourcePath
if (-not (Test-Path $resolvedSource)) {
    Write-Error "Source not found: $resolvedSource"
}
if (-not $OutputExe) {
    $OutputExe = Join-Path (Split-Path $PSScriptRoot -Parent) "wsl-fleet.exe"
} elseif (-not [System.IO.Path]::IsPathRooted($OutputExe)) {
    $OutputExe = Join-Path $PSScriptRoot $OutputExe
}

# 2. The C# compiler Windows ships: nothing to install, and an exe every
# machine runs.
$cscPath = Join-Path $env:windir "Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path $cscPath)) {
    $cscPath = Join-Path $env:windir "Microsoft.NET\Framework\v4.0.30319\csc.exe"
}
if (-not (Test-Path $cscPath)) {
    Write-Error "The C# compiler (csc.exe) was not found."
}

# 3. A console exe - the caller's shell waits for it and its output, and the
# double-click's own console is hidden at once - the icon worn, WinForms for
# its boxes.
$compilerArgs = @(
    "/nologo",
    "/target:exe",
    "/optimize+",
    "/r:System.Windows.Forms.dll",
    "/out:$OutputExe",
    $resolvedSource
)

$resolvedIcon = Join-Path $PSScriptRoot $IconPath
if (Test-Path $resolvedIcon) {
    $compilerArgs += "/win32icon:$resolvedIcon"
}

# 4. Compiled.
Write-Host "Building $OutputExe from $SourcePath..."
& $cscPath $compilerArgs

if ($LASTEXITCODE -eq 0 -and (Test-Path $OutputExe)) {
    Write-Host "The launcher is ready: $(Resolve-Path $OutputExe)"
} else {
    Write-Error "The build failed (exit code $LASTEXITCODE)."
}
