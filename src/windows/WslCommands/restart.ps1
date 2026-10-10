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
    # Controllers\Restart.ps1) renders them: the instance. This file never
    # asks.
    [object]$Form
)

$ErrorActionPreference = "Stop"

$Distro = $Form.Instance
$DistroName = $Distro.Name

# The one gesture, the engine's: the stop comes first, WSL reads /etc/wsl.conf
# when the instance boots again - the point of the command. A half that fails
# is named by the engine's own refusal.
Write-Host ""
Write-Host "==> Restarting '$DistroName'..." -ForegroundColor (Get-MessageColour info)
Write-Host ""
try {
    $Distro = $Manager.Restart($Distro)
} catch {
    Write-Host ""
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor (Get-MessageColour error)
    exit 1
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor (Get-MessageColour success)
Write-Host "       '$DistroName' is running again" -ForegroundColor (Get-MessageColour success)
Write-Host "============================================================" -ForegroundColor (Get-MessageColour success)
Write-Host ""
Write-Host "  * Install folder   : " -NoNewline; Write-Host "$($Distro.Path)" -ForegroundColor (Get-MessageColour info)
Write-Host "  * Disk file        : " -NoNewline; Write-Host "$(Format-Size ($Distro.DiskBytes()))" -ForegroundColor (Get-MessageColour info)
Write-Host ""
Write-Host ""
