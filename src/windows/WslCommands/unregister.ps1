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
    # Controllers\Unregister.ps1) renders them: the instance, and whether a
    # copy is taken before it goes. This file never asks.
    [object]$Form
)

$ErrorActionPreference = "Stop"

$Distro = $Form.Instance
$ArchiveFirst = $Form.ArchiveFirst
$DistroName = $Distro.Name
$InstallPath = $Distro.Path

Write-Host "==> Stopping the distro processes..." -ForegroundColor (Get-MessageColour info)
Write-Host "==> Unregistering the distro..." -ForegroundColor (Get-MessageColour info)

# Hand execution to the engine: executes Archive if requested, unregisters, cleans folders and refreshes state
try {
    $Report = $Manager.Unregister($Distro, $ArchiveFirst)
    $Removed = $Report.Removed
} catch {
    Write-Host ""
    Write-Host "[ERROR] Could not unregister '$DistroName': $($_.Exception.Message)" -ForegroundColor (Get-MessageColour error)
    exit 1
}

# ==============================================================================
# 3. WHAT BECAME OF IT (reported; the removal itself was the instance's)
# ==============================================================================
if ($Removed.FolderState -eq "removed") {
    Write-Host "==> Removing installation folder ($InstallPath)..." -ForegroundColor (Get-MessageColour info)
} elseif ($Removed.FolderState -eq "removed with the distribution") {
    Write-Host "==> Installation folder already gone - wsl --unregister removes it with the distribution." -ForegroundColor (Get-MessageColour info)
} else {
    Write-Host "==> No installation folder found ($InstallPath)." -ForegroundColor (Get-MessageColour info)
}

# ==============================================================================
# 4. WINDOWS TERMINAL AND DOCKER (reported; the cleaning was the instance's)
# ==============================================================================
Write-Host "==> Cleaning Windows Terminal leftovers..." -ForegroundColor (Get-MessageColour info)
foreach ($SettingsPath in $Removed.Unreadable) {
    Write-Host "  * settings.json : ghost entries NOT pruned in $SettingsPath" -ForegroundColor (Get-MessageColour warning)
    Write-Host "                    (unreadable JSON - a // comment breaks ConvertFrom-Json; remove them by hand)" -ForegroundColor (Get-MessageColour muted)
}
if ($Removed.GhostsPruned -gt 0) {
    Write-Host "  * settings.json : pruned $($Removed.GhostsPruned) ghost '$DistroName' entries" -ForegroundColor (Get-MessageColour success)
}
if ($Removed.FragmentsRemoved -gt 0) {
    Write-Host "  * fragments     : removed $($Removed.FragmentsRemoved) appearance file(s)" -ForegroundColor (Get-MessageColour success)
}
if ($Removed.DockerError) {
    Write-Host "  * Docker Desktop : list not updated ($($Removed.DockerError))" -ForegroundColor (Get-MessageColour warning)
} elseif ($Removed.DockerRemoved) {
    Write-Host "  * Docker Desktop : '$DistroName' removed from the integrated distros" -ForegroundColor (Get-MessageColour success)
}

# ==============================================================================
# SUMMARY
# ==============================================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor (Get-MessageColour success)
Write-Host "                WSL Stack Instance Removed!                 " -ForegroundColor (Get-MessageColour success)
Write-Host "============================================================" -ForegroundColor (Get-MessageColour success)
Write-Host ""
Write-Host "  * Distro          : " -NoNewline; Write-Host "$DistroName" -ForegroundColor (Get-MessageColour info)
Write-Host "  * Install folder  : " -NoNewline
if ($Removed.FolderState -eq "removed") {
    Write-Host "$($Removed.FolderState)" -ForegroundColor (Get-MessageColour success)
} else {
    Write-Host "$($Removed.FolderState)" -ForegroundColor (Get-MessageColour muted)
}
Write-Host "  * Terminal ghosts : " -NoNewline; Write-Host "$($Removed.GhostsPruned) pruned" -ForegroundColor (Get-MessageColour info)
Write-Host "  * Fragments       : " -NoNewline; Write-Host "$($Removed.FragmentsRemoved) removed" -ForegroundColor (Get-MessageColour info)

if ($Report.Archive) {
    Write-Host "  * Backup archive  : " -NoNewline; Write-Host "$($Report.Archive.Destination)" -ForegroundColor (Get-MessageColour success)
}

Write-Host ""
Write-Host " Restart Windows Terminal to refresh the profile list."
Write-Host ""