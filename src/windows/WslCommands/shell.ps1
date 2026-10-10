# The classes this file names, pulled in by the file itself: a type resolves
# for its own reader, whoever launched the command.
using module ..\WslModel\WslModel.psd1
[CmdletBinding()]
param (
    # Injected by wsl.ps1 - the engine every command acts through, made once
    # in the entry. A command is never run by hand any more: the entry loads
    # the module and hands this over, and the `using` above names the type, so
    # it binds from the first line.
    [WslInstanceManager]$Manager
)

$ErrorActionPreference = "Stop"

$Distro = Select-Distro -Manager $Manager

Write-Host ""
Write-Host "==> Opening a shell in '$Distro.Name'..." -ForegroundColor (Get-MessageColour info)

exit $Manager.Shell($Distro)
