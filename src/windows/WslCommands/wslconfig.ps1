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

Write-Host ""
Write-Host "==> Opening .wslconfig" -ForegroundColor (Get-MessageColour info)
try {
    $Report = $Manager.WslConfig()
} catch {
    Write-Host ""
    Write-Host "[WARNING] .wslconfig could not be open: $($_.Exception.Message)" -ForegroundColor (Get-MessageColour warning)
    exit 1
}
$Path = $Report.Path

if ($Report.Created) {
    Write-Host "  * .wslconfig : " -NoNewline
    Write-Host "file created" -ForegroundColor (Get-MessageColour success)
} else {
    Write-Host "  * .wslconfig : " -NoNewline
    Write-Host "$Path" -ForegroundColor (Get-MessageColour info)
}
