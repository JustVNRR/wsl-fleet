using module ..\Services\ServiceFactory.psm1

param(
    [string]$Name,
    [string]$Arg1,
    [string]$Arg2,
    [string]$Assets,
    [string]$Root
)

$distroTree = ""
$candidate = Join-Path $PSScriptRoot "..\..\..\src\distro"
if (Test-Path $candidate) { $distroTree = (Resolve-Path $candidate).Path }

try {
    $fleet = [ServiceFactory]::CreateFleetService($Root, $Assets, $distroTree)

    Write-Host "Moving the fleet to '$Name'..."
    $r = $fleet.Migrate($Name)
    $count = @($r.Moved).Count
    $what = if ($count -eq 0) { "the archives" } else { ($r.Moved -join ', ') + " and the archives" }
    Write-Host "Moved $what to '$($r.Target)'."
    Write-Host "Restore them on the other side with  .\wsl-fleet.ps1 restore"
    exit 0
} catch {
    Write-Host ("FAILED: " + ($_.Exception.Message -replace "`r?`n", " "))
    exit 1
}
