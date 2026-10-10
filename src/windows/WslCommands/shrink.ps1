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
    # Controllers\Shrink.ps1) renders them: the instance, and whether the
    # safety copy is taken. This file never asks.
    [object]$Form
)

$ErrorActionPreference = "Stop"

$Distro = $Form.Instance
$DistroName = $Distro.Name
$ArchiveFirst = $Form.ArchiveFirst

# The window's gate warning, in the same words - said here too, no
# condition: the stop belongs to the safety copy, and a warning costs
# nothing.
Write-Host ""
Write-Host "  WARNING: THE INSTANCE WILL BE STOPPED." -ForegroundColor (Get-MessageColour warning)
Write-Host "  Make sure nothing is running inside." -ForegroundColor (Get-MessageColour muted)

$BeforeBytes = $Distro.DiskBytes()

Write-Host ""
Write-Host "==> Reclaiming space in '$DistroName'" -ForegroundColor (Get-MessageColour info)
Write-Host "  * Disk file now    : $(Format-Size $BeforeBytes)" -ForegroundColor (Get-MessageColour muted)
Write-Host ""
Write-Host "  This compacts the instance's virtual disk: the space its filesystem has" -ForegroundColor (Get-MessageColour muted)
Write-Host "  freed over time comes back to Windows. Nothing inside is touched." -ForegroundColor (Get-MessageColour muted)

if ($ArchiveFirst) {
    Write-Host "==> Creating safety archive..." -ForegroundColor (Get-MessageColour info)
}

# 3. The whole gesture, delegated to the engine - the safety copy first when
# asked (a failed one stops everything: nothing is compacted), then the
# compact, and a running instance comes back up. Its refusals are two
# voices: the copy's, and the compact's.
Write-Host ""
Write-Host "==> Compacting the virtual disk..." -ForegroundColor (Get-MessageColour info)
try {
    $Report = $Manager.Shrink($Distro, $ArchiveFirst)
} catch {
    Write-Host ""
    if ($_.Exception.Message -like "The archive did not complete*") {
        Write-Host "[ABORT] $($_.Exception.Message)" -ForegroundColor (Get-MessageColour error)
        Write-Host "        The instance is exactly as it was." -ForegroundColor (Get-MessageColour muted)
    } else {
        Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor (Get-MessageColour error)
        Write-Host "        The instance is untouched." -ForegroundColor (Get-MessageColour muted)
    }
    exit 1
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor (Get-MessageColour success)
Write-Host "       '$DistroName' compacted" -ForegroundColor (Get-MessageColour success)
Write-Host "============================================================" -ForegroundColor (Get-MessageColour success)
Write-Host ""
Write-Host "  * Disk file        : " -NoNewline
Write-Host "$(Format-Size $Report.Before) -> $(Format-Size $Report.After)" -ForegroundColor (Get-MessageColour info)
if ($Report.Freed -gt 0) {
    Write-Host "  * Reclaimed        : " -NoNewline; Write-Host "$(Format-Size $Report.Freed)" -ForegroundColor (Get-MessageColour success)
} else {
    Write-Host "  * Reclaimed        : " -NoNewline
    Write-Host "nothing - the disk held no space to give back" -ForegroundColor (Get-MessageColour muted)
}

# 4. Left the way it was found (reported from the engine's return).
if ($Report.WasRunning) {
    if ($Report.Restarted) {
        Write-Host "'$DistroName' is running again." -ForegroundColor (Get-MessageColour success)
    } else {
        Write-Host "Could not start '$DistroName' - start it with: wsl -d $DistroName" -ForegroundColor (Get-MessageColour warning)
    }
    Write-Host ""
}
