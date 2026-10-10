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
    # Controllers\AddPack.ps1) renders them: the instance and the pack.
    # This file never asks.
    [object]$Form
)

# The pack's folder is copied into the instance, its root half runs first as
# WSL's own root, then its install script - the engine's gesture; the lines
# are here.

$ErrorActionPreference = "Stop"

$Distro = $Form.Instance
$DistroName = $Distro.Name
$PackName = $Form.Pack

# The request, passed on whole: the instance resolves what the pack brings,
# skips what it already carries, and installs the rest.
Write-Host ""
Write-Host "==> Installing '$PackName' in '$DistroName'..." -ForegroundColor (Get-MessageColour info)

$Report = $Manager.AddPack($Distro, $PackName)

# Exit code 2: the pack asked a question and the answer was no (the
# oh_my_code pack asks about a second copy installed on Windows). Its folder
# went back out, and the command ends on exit 0: nothing is broken, nothing
# to run again.
if ($Report.Outcome -eq "declined") {
    Write-Host "       The pack's files were removed: it is not installed in '$DistroName'." -ForegroundColor (Get-MessageColour hint)
    exit 0
}

if ($Report.Outcome -eq "copy-failed") {
    Write-Host "[ABORT] Could not copy the pack's files into '$DistroName' (exit code $($Report.ExitCode))." -ForegroundColor (Get-MessageColour error)
    Write-Host "        The message above says what refused: the instance, or Windows." -ForegroundColor (Get-MessageColour hint)
    exit $Report.ExitCode
}

# A half-installed pack is worse than none: the Makefile loads whatever folder
# is there, so the menu would offer commands whose tool was never installed.
# The folder went back out - and only it: what the install already wrote stays,
# and running this again picks up there.
if ($Report.Outcome -eq "failed") {
    Write-Host ""
    Write-Host "[FAIL] The installation did not complete (exit code $($Report.ExitCode))." -ForegroundColor (Get-MessageColour error)
    Write-Host "       The pack's files were removed." -ForegroundColor (Get-MessageColour hint)
    Write-Host "       Whatever the install had already put in place is still there - run this again to finish." -ForegroundColor (Get-MessageColour hint)
    exit $Report.ExitCode
}

# What happened, short: what went in, and what the pack brought that was
# already there.
Write-Host ""
if ($Report.Installed.Count -gt 0) {
    Write-Host "       Installed: $($Report.Installed -join ', ')" -ForegroundColor (Get-MessageColour success)
}
if ($Report.Skipped.Count -gt 0) {
    Write-Host "       Already there: $($Report.Skipped -join ', ')" -ForegroundColor (Get-MessageColour muted)
}

exit 0
