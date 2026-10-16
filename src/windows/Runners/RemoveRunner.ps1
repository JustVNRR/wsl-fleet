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

    Write-Stamp "removing '$Name'"
    $dto = [RemoveDto]::new()
    $dto.InstanceName = $Name
    $dto.ArchiveFirst = [bool]::Parse($Arg1)
    $service.Remove($dto)
    $note = if ($dto.ArchiveFirst) { " (archived as '${Name}_archive' first)" } else { "" }
    Write-Stamp ("RESULT OK " + $Name + ": removed" + $note)
    exit 0
} catch {
    Write-Stamp ("RESULT FAIL " + ($_.Exception.Message -replace "`r?`n", " "))
    exit 1
}
