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
    # Controllers\ManagePacks.ps1) renders them: the instance and the
    # checklist's two lists. This file never asks.
    [object]$Form
)

# Every pack this checkout carries was shown, the ones the instance already
# had arrived checked, and what came back is applied - the missing ones
# installed, the unchecked ones taken out.

$ErrorActionPreference = "Stop"

$Distro = $Form.Instance
$DistroName = $Distro.Name
$ToAdd = @($Form.ToAdd)
$ToRemove = @($Form.ToRemove)

# What is about to happen, said from the checklist's lists - then the
# engine's own applying.
Write-Host ""
if ($ToAdd.Count -gt 0) {
    Write-Host "==> Installing: $(@($ToAdd | ForEach-Object { $_.Name }) -join ', ')" -ForegroundColor (Get-MessageColour info)
}
if ($ToRemove.Count -gt 0) {
    Write-Host "==> Removing: $($ToRemove -join ', ')" -ForegroundColor (Get-MessageColour info)
}

$Report = $Manager.ManagePacks($Distro, $ToAdd, $ToRemove)

# A failure names the pack, its step and its code; the packs already applied
# stay.
if ($null -ne $Report.Failure) {
    Write-Host ""
    Write-Host "[FAIL] '$($Report.Failure.Pack)' did not complete ($($Report.Failure.Step), exit code $($Report.Failure.ExitCode))." -ForegroundColor (Get-MessageColour error)
    Write-Host "       The packs already applied stay - run this again to finish." -ForegroundColor (Get-MessageColour hint)
    exit $Report.ExitCode
}

# Where things stand, read back through the engine's report
$Now = @($Report.Now)
Write-Host ""
Write-Host "==> '$DistroName' now carries: $(if ($Now.Count -gt 0) { $Now -join ', ' } else { 'no pack' })" -ForegroundColor (Get-MessageColour success)
if ($ToAdd.Count -gt 0) {
    Write-Host "    Open a shell in it to use them:  .\wsl.ps1 shell" -ForegroundColor (Get-MessageColour muted)
}
exit 0
