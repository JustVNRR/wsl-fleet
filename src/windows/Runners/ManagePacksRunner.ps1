using module ..\Services\ServiceFactory.psm1
using module ..\Dtos\InstanceDto.psm1

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
    $service = [ServiceFactory]::CreateInstanceService($Root, $Assets, $distroTree)

    $dto = [ManagePacksDto]::new()
    $dto.InstanceName = $Name
    $dto.ToAdd = @($Arg1 -split ',' | Where-Object { $_ })
    $dto.ToRemove = @($Arg2 -split ',' | Where-Object { $_ })
    Write-Host "Managing the packs of '$Name'..."
    $r = $service.ManagePacks($dto)
    Write-Host "Outcome: $($r.Outcome)"
    foreach ($line in @($r.Installed)) { Write-Host "  installed: $line" }
    foreach ($line in @($r.Removed)) { Write-Host "  removed:   $line" }
    foreach ($line in @($r.Failed)) { Write-Host "  FAILED:    $line" }
    if ($r.ExitCode -ne 0) { exit 1 }
    exit 0
} catch {
    Write-Host ("FAILED: " + ($_.Exception.Message -replace "`r?`n", " "))
    exit 1
}
