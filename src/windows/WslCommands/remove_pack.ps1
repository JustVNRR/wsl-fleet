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
    # Controllers\RemovePack.ps1) renders them: the instance and the pack.
    # This file never asks.
    [object]$Form
)

# The pack's own remove.sh runs first - the copy INSIDE the instance, not the
# one in this checkout: what has to come out is what the code that installed
# it put in, and that code travelled with the pack. Then the folder goes, and
# the gmake menu loses the commands with it.

$ErrorActionPreference = "Stop"

$Distro = $Form.Instance
$DistroName = $Distro.Name
$PackName = $Form.Pack

# The request, passed on whole: the instance resolves what leaves with the
# pack, refuses a still-claimed one, and runs the removals.
Write-Host ""
Write-Host "==> Removing '$PackName' from '$DistroName'..." -ForegroundColor (Get-MessageColour info)

$Report = $Manager.RemovePack($Distro, $PackName)

# A pack a still-installed pack requires does not leave: the removal would
# break what stays.
if ($Report.Outcome -eq "conflict") {
    Write-Host ""
    foreach ($Conflict in $Report.Conflicts) {
        Write-Host ("[ABORT] '{0}' cannot be removed: required by {1}." -f $Conflict.Name, ($Conflict.Blockers -join " and ")) -ForegroundColor (Get-MessageColour error)
        Write-Host ("        Take {0} out first, or leave '{1}' where it is." -f ($Conflict.Blockers -join " and "), $Conflict.Name) -ForegroundColor (Get-MessageColour hint)
    }
    exit 1
}

# The folder stays when the script failed: the pack is still half in place, and
# its files are what a second attempt needs.
if ($Report.Outcome -eq "self-failed") {
    Write-Host ""
    Write-Host "[FAIL] The pack could not remove itself (exit code $($Report.ExitCode))." -ForegroundColor (Get-MessageColour error)
    Write-Host "       Nothing was deleted: '$($Report.Name)' is still installed in '$DistroName'." -ForegroundColor (Get-MessageColour hint)
    exit $Report.ExitCode
}

if ($Report.Outcome -eq "folder-failed") {
    Write-Host ""
    Write-Host "[FAIL] The pack's folder could not be deleted (exit code $($Report.ExitCode))." -ForegroundColor (Get-MessageColour error)
    Write-Host "       '$($Report.Name)' is out of the gmake menu, but its files are still in the instance." -ForegroundColor (Get-MessageColour warning)
    exit $Report.ExitCode
}

# What left, and what went with the pack - read from the report.
$Also = @($Report.Removed | Where-Object { $_ -ne $PackName })
foreach ($Name in $Also) {
    Write-Host "    '$Name' goes with '$PackName': nothing installed requires it any more." -ForegroundColor (Get-MessageColour muted)
}
if ($Report.Missing.Count -gt 0) {
    Write-Host "    No remove.sh in: $($Report.Missing -join ', ') - installed before packs had one." -ForegroundColor (Get-MessageColour warning)
    Write-Host "    Nothing of it is undone on the system side: only its files leave." -ForegroundColor (Get-MessageColour hint)
    Write-Host "    To take its tool out by hand, open a shell in '$DistroName'." -ForegroundColor (Get-MessageColour hint)
}

# The dependencies their remove.sh never named are taken back by the
# engine, silently: only a cleanup that stopped early is worth a line.
if (-not $Report.Cleaned) {
    # The packs are out either way; this is the tidy-up, not the removal.
    Write-Host ""
    Write-Host "[WARN] The cleanup stopped early (exit code $($Report.CleanupCode))." -ForegroundColor (Get-MessageColour warning)
    Write-Host "       They are gone, but some of their dependencies may remain." -ForegroundColor (Get-MessageColour hint)
}

Write-Host ""
Write-Host "$($Report.Removed -join ', ') successfully uninstalled." -ForegroundColor (Get-MessageColour success)
exit 0
