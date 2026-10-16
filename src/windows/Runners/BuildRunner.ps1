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
    $raw = [System.IO.File]::ReadAllText($Arg1) | ConvertFrom-Json
    Remove-Item -LiteralPath $Arg1 -ErrorAction SilentlyContinue

    $dto = [BuildDto]::new()
    $dto.Name = "$($raw.Name)"
    $dto.User = "$($raw.User)"
    $dto.BuildType = [WslBuildType]"$($raw.BuildType)"
    $dto.BuildPath = "$($raw.BuildPath)"
    $dto.Context = "$($raw.Context)"
    $dto.Onboarding = "$($raw.Onboarding)"
    $dto.Packs = @($raw.Packs | Where-Object { $_ } | ForEach-Object { "$_" })
    $dto.KeepImage = [bool]$raw.KeepImage
    $dto.RegisterDocker = [bool]$raw.RegisterDocker

    $service = [ServiceFactory]::CreateInstanceService($Root, $Assets,$distroTree)

    Write-Host "Creating '$($dto.Name)'..."
    $r = $service.Build($dto)
    foreach ($line in @($r.Messages)) { Write-Host "$line" }
    if ("$($r.Status)" -notin @("Ok", "Warning")) { exit 1 }

    try {
        Write-Host "Opening a shell into '$($dto.Name)'..."
        $null = $service.Open($dto.Name)
    } catch {
        Write-Host "The shell window could not be opened: $($_.Exception.Message)"
    }
    exit 0
} catch {
    Write-Host ("FAILED: " + ($_.Exception.Message -replace "`r?`n", " "))
    exit 1
}
