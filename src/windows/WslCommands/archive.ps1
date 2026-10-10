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
    # Controllers\Archive.ps1) renders them: the instance, the name, the
    # format, the stopping's permit, and whether the instance is kept. This
    # file never asks.
    [object]$Form
)

$ErrorActionPreference = "Stop"

$Distro = $Form.Instance
$DistroName = $Distro.Name
$Chosen = $Form.Name
$Format = $Form.Format

# The cost comes from the engine before it costs it: the disk's size, the
# free room, where the archive will land.
$Cost = $Manager.ArchiveCost($Distro, $Chosen, $Format)

# The proposal never lands on a taken name, so a taken one here is a typed
# name - and typing an existing name is how an archive is replaced. Said,
# not done quietly.
if ($Manager.HasArchive($Chosen)) {
    Write-Host "  '$Chosen' exists: replacing its archive." -ForegroundColor (Get-MessageColour warning)
}

Write-Host ""
Write-Host "==> Backing up '$DistroName'" -ForegroundColor (Get-MessageColour info)
Write-Host "  * Instance disk    : $(Format-Size $Cost.DiskBytes)" -ForegroundColor (Get-MessageColour muted)
Write-Host "  * Free on target   : $(Format-Size $Cost.FreeBytes)" -ForegroundColor (Get-MessageColour muted)
Write-Host "  * Archive          : $($Cost.Destination) ($Format)" -ForegroundColor (Get-MessageColour muted)

if ($Cost.DiskBytes -gt 0 -and $Cost.FreeBytes -lt $Cost.DiskBytes) {
    Write-Host "  * Note             : less free space than the disk's size." -ForegroundColor (Get-MessageColour warning)
    Write-Host "                       The archive holds used data and is normally much smaller;" -ForegroundColor (Get-MessageColour muted)
    Write-Host "                       if it does not fit, the export stops and its partial file is deleted." -ForegroundColor (Get-MessageColour muted)
}

# The export - the instance's own gesture: it stops itself for a consistent
# read (the conversation's permit), writes the tar, and comes back up when
# the stopping was its own. The look follows in the engine; a partial tar is
# removed before the failure travels.
$Started = Get-Date
try {
    $Report = $Manager.Archive($Distro, $Chosen, $Format, $Form.Permit)
} catch {
    Write-Host ""
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor (Get-MessageColour error)
    Write-Host "        The partial archive was removed. Nothing else was modified." -ForegroundColor (Get-MessageColour muted)
    exit 1
}

$Archive = $Report.Archive
$Elapsed = (Get-Date) - $Started

Write-Host ""
Write-Host "============================================================" -ForegroundColor (Get-MessageColour success)
Write-Host "       Backup of '$DistroName' written" -ForegroundColor (Get-MessageColour success)
Write-Host "============================================================" -ForegroundColor (Get-MessageColour success)
Write-Host ""
# The look goes next to the tar, once the export succeeded: a half-written
# archive folder is worse than one missing the look.
$Look = $Report.Look
Write-Host "  * Look             : font '$($Look.Font)', colours '$($Look.ColorScheme)'$(if ($Look.IconCopied) { ", icon copied" })" -ForegroundColor (Get-MessageColour muted)
Write-Host "  * Docker Desktop   : $(if ($Look.Docker -eq "yes") { "knows this instance" } elseif ($Look.Docker -eq "no") { "does not know it" } else { "not installed, or unreadable" })" -ForegroundColor (Get-MessageColour muted)
if (-not (Test-FontInstalled $Look.Font)) {
    Write-Host "                       '$($Look.Font)' is not installed on Windows" -ForegroundColor (Get-MessageColour warning)
}

Write-Host "  * Archive          : " -NoNewline; Write-Host "$($Report.ArchiveDir)" -ForegroundColor (Get-MessageColour info)
Write-Host "  * Tar              : " -NoNewline; Write-Host "$($Archive.Name) ($(Format-Size $Archive.Length))" -ForegroundColor (Get-MessageColour info)
Write-Host "  * Instance disk    : " -NoNewline; Write-Host "$(Format-Size $Cost.DiskBytes)" -ForegroundColor (Get-MessageColour info)
Write-Host "  * Time             : " -NoNewline; Write-Host "$([int]$Elapsed.TotalMinutes) min $($Elapsed.Seconds) s" -ForegroundColor (Get-MessageColour info)
Write-Host ""
Write-Host "------------------------------------------------------------" -ForegroundColor (Get-MessageColour muted)
Write-Host "To restore it as a new instance:" -ForegroundColor (Get-MessageColour hint)
Write-Host "  .\wsl.ps1 restore        (it lists the archives, this one included)" -ForegroundColor (Get-MessageColour hint)
Write-Host "------------------------------------------------------------" -ForegroundColor (Get-MessageColour muted)
Write-Host ""

# What becomes of the instance: kept, in the state it was found - the
# instance put itself back. A removal it asked for is the entry's ending,
# after this returns: no command calls another one.
if (-not $Form.Delete) {
    if ($Report.Stopped) {
        Write-Host "'$DistroName' is running again." -ForegroundColor (Get-MessageColour success)
        Write-Host ""
    } else {
        Write-Host "'$DistroName' is left stopped." -ForegroundColor (Get-MessageColour muted)
        Write-Host ""
    }
}
