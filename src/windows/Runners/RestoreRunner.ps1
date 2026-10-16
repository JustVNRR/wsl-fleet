using module ..\Services\ServiceFactory.psm1
using module ..\Dtos\InstanceDto.psm1

param(
    [string]$Name,
    [string]$Arg1,
    [string]$Arg2,
    [string]$Assets,
    [string]$Root
)

$Log = Join-Path $env:TEMP "wsl-fleet-gui-job.log"
function Write-Stamp($Message) { $null = Add-Content -LiteralPath $Log -Value "$(Get-Date -Format HH:mm:ss) $Message" }

$distroTree = ""
$candidate = Join-Path $PSScriptRoot "..\..\..\src\distro"
if (Test-Path $candidate) { $distroTree = (Resolve-Path $candidate).Path }

try {
    $service = [ServiceFactory]::CreateInstanceService($Root, $Assets, $distroTree)

    Write-Stamp "restoring '$Name' as '$Arg1'"
    $dto = [RestoreDto]::new()
    $dto.ArchiveName = $Name
    $dto.InstanceName = $Arg1
    $built = $service.Restore($dto).InstanceName
    Write-Stamp ("RESULT OK " + $built + ": restored from '" + $Name + "'")
    exit 0
} catch {
    Write-Stamp ("RESULT FAIL " + ($_.Exception.Message -replace "`r?`n", " "))
    exit 1
}
