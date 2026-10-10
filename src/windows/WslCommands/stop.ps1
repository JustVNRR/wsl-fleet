# The classes this file names, pulled in by the file itself: a type resolves
# for its own reader, whoever launched the command.
using module ..\WslModel\WslModel.psd1
[CmdletBinding()]
param (
    # Injected by wsl.ps1 - the engine every command acts through, made once
    # in the entry. A command is never run by hand any more: the entry loads
    # the module and hands this over, and the `using` above names the type, so
    # it binds from the first line.
    [WslInstanceManager]$Manager,

    # The answers, whole - the console's conversation (src\windows\cli\
    # Controllers\Stop.ps1) renders them: the instance. This file never asks.
    [object]$Form
)

$ErrorActionPreference = "Stop"

$Distro = $Form.Instance
$DistroName = $Distro.Name

Write-Host ""
Write-Host "==> Stopping '$DistroName'..." -ForegroundColor (Get-MessageColour info)
try {
    $Distro = $Manager.Stop($Distro)
} catch {
    Write-Host ""
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor (Get-MessageColour error)
    Write-Host "        '$DistroName' may still be running." -ForegroundColor (Get-MessageColour muted)
    exit 1
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor (Get-MessageColour success)
Write-Host "       '$DistroName' is stopped" -ForegroundColor (Get-MessageColour success)
Write-Host "============================================================" -ForegroundColor (Get-MessageColour success)
Write-Host ""
Write-Host "  * Install folder   : " -NoNewline; Write-Host "$($Distro.Path)" -ForegroundColor (Get-MessageColour info)
Write-Host "  * Disk file        : " -NoNewline; Write-Host "$(Format-Size ($Distro.DiskBytes()))" -ForegroundColor (Get-MessageColour info)
Write-Host ""
Write-Host "  Nothing on the disk was touched: closing an instance only ends what" -ForegroundColor (Get-MessageColour muted)
Write-Host "  was running. Start it again with  .\wsl.ps1 start" -ForegroundColor (Get-MessageColour muted)
Write-Host ""