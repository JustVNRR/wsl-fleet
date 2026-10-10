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
    # Controllers\Migrate.ps1) renders them: the folder the fleet goes to.
    # This file never asks.
    [object]$Form
)

# The fleet moved to another folder, the registry never touched: every
# instance is ARCHIVED (the tar and its look - our own archive), then
# unregistered right away - the space frees as it goes, the disk never
# doubles - and when nothing is left but the archives folder, that folder
# travels (the engine's own voyage: a rename on one volume, robocopy across,
# the originals kept). The working folder follows - but only once everything
# made it. The instances come back on the target side with .\wsl.ps1
# restore.

$ErrorActionPreference = "Stop"

$Target = $Form.Target
$SourceBase = $Manager.InstancesRoot

# 1. The whole fleet: ours, under the working folder. Nothing to choose - it
# is the folder that moves. A fleet of zero is fine: the archives travel all
# the same, and with nothing at all the switch still happens - a target can
# be chosen before anything is built.
$Fleet = @($Manager.WslRegisteredInstances() |
    Where-Object { (Split-Path -Path $_.Path -Parent).TrimEnd('\') -eq $SourceBase.TrimEnd('\') } |
    Sort-Object Name)
if ($Fleet.Count -eq 0) {
    Write-Host ""
    Write-Host "  No instance of ours in '$SourceBase' - nothing to archive; the archives travel all the same." -ForegroundColor (Get-MessageColour muted)
}

Write-Host ""
Write-Host "==> Archiving the fleet" -ForegroundColor (Get-MessageColour info)
Write-Host "  Instances that run are stopped one by one as they are archived - anything" -ForegroundColor (Get-MessageColour muted)
Write-Host "  unsaved in them is lost. Docker Desktop and the others keep running." -ForegroundColor (Get-MessageColour muted)

# 2. One by one: archived, then unregistered - the space frees as it goes. A
# failure stops the run there; what is already archived is unregistered, so
# running the command again picks up with the rest.
$Done = 0
foreach ($Instance in $Fleet) {
    Write-Host ""
    Write-Host "  * $($Instance.Name)" -ForegroundColor (Get-MessageColour info)
    try {
        $null = $Manager.Unregister($Instance, $true)
    } catch {
        Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor (Get-MessageColour error)
        break
    }
    Write-Host "    archived, then removed (the copy is in '$($Manager.ArchivesRoot)')." -ForegroundColor (Get-MessageColour muted)
    $Done++
}

if ($Done -ne $Fleet.Count) {
    Write-Host ""
    Write-Host "  * Working folder: $SourceBase (unchanged)" -ForegroundColor (Get-MessageColour warning)
    Write-Host "    $($Fleet.Count - $Done) instance(s) not archived - nothing moves until the whole fleet is." -ForegroundColor (Get-MessageColour muted)
    Write-Host "    The ones already archived are gone - run it again to carry on with the rest." -ForegroundColor (Get-MessageColour hint)
    exit 1
}

# 3. Nothing left but the archives: they travel - the engine's own voyage. A
# failure is said, and the working folder does NOT follow: the source is
# still whole.
Write-Host ""
try {
    $Voyage = $Manager.MoveArchives($Target)
} catch {
    Write-Host "    [FAIL] $($_.Exception.Message)" -ForegroundColor (Get-MessageColour error)
    exit 1
}
if ($Voyage.Moved) {
    Write-Host "  * Archives: $($Voyage.Old) -> $($Voyage.New)" -ForegroundColor (Get-MessageColour info)
    Write-Host "    done." -ForegroundColor (Get-MessageColour muted)
}

# 4. The working folder follows.
[WslInstanceManager]::SetRoot($Voyage.Target)
Write-Host ""
Write-Host "  * Working folder: $($Voyage.Target)" -ForegroundColor (Get-MessageColour success)
if (Test-Path $Voyage.New) {
    Write-Host "    The instances are in '$($Voyage.New)' - bring them back with  .\wsl.ps1 restore" -ForegroundColor (Get-MessageColour hint)
}
if ($Voyage.Kept -and (Test-Path $Voyage.Old)) {
    Write-Host "    The originals under '$($Voyage.Old)' were kept - delete them after making sure everything is OK." -ForegroundColor (Get-MessageColour hint)
}
