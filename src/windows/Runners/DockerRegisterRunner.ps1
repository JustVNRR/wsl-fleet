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
    $restart = ("$Arg2" -eq "True")

    if ($Arg1 -eq "unregister") {
        Write-Stamp "taking '$Name' out of Docker Desktop"
        $dto = [UnregisterDockerDto]::new()
        $dto.InstanceName = $Name
        $dto.Restart = $restart
        $response = $service.UnregisterDocker($dto)
        $tail = switch ("$($response.Restart)") {
            "restarted" { "Docker Desktop restarted" }
            "pending"   { "Docker Desktop would not restart - it will be gone at its next start" }
            default     { "it will be gone at Docker Desktop's next start" }
        }
        Write-Stamp ("RESULT OK '$Name' is out of Docker Desktop - " + $tail + ".")
        exit 0
    }

    Write-Stamp "registering '$Name' with Docker Desktop"
    $dto = [RegisterDockerDto]::new()
    $dto.InstanceName = $Name
    $dto.Restart = $restart
    $response = $service.RegisterDocker($dto)
    $tail = switch ("$($response.Restart)") {
        "restarted" { "Docker Desktop restarted" }
        "started"   { "Docker Desktop started" }
        "pending"   { "Docker Desktop would not restart - it will be seen at its next start" }
        default     { "it will be seen at Docker Desktop's next start" }
    }
    Write-Stamp ("RESULT OK '$Name' is registered with Docker Desktop - " + $tail + ".")
    exit 0
} catch {
    Write-Stamp ("RESULT FAIL " + ($_.Exception.Message -replace "`r?`n", " "))
    exit 1
}
