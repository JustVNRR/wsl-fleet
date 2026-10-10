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
    # Controllers\Restore.ps1) renders them: the archive, the name of the new
    # instance, and the Docker word. This file never asks.
    [object]$Form
)

$ErrorActionPreference = "Stop"

$Chosen = $Form.Instance
$Name = $Form.Name
$AddDocker = $Form.AddDocker

# Import. Version 2, like build.ps1: a tar does not carry the version it
# came from, and WSL 1 is not what this repository builds. The import, the
# marker, the look and Docker's entry are the engine's - the Docker word of
# the conversation is the one it acts on.
# The tar itself, for the line below - read from the row, which owns it.
$ChosenTar = $Chosen.ArchiveTar()

Write-Host ""
Write-Host "==> Creating '$Name' from $($Chosen.Name)" -ForegroundColor (Get-MessageColour info)
Write-Host "  * Archive          : $($ChosenTar.FullName) ($(Format-Size $ChosenTar.Length))" -ForegroundColor (Get-MessageColour muted)
Write-Host ""

try {
    $Report = $Manager.RestoreFromArchive($Chosen.ArchivePath, $Name, $AddDocker)
} catch {
    Write-Host ""
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor (Get-MessageColour error)
    Write-Host "        The archive is untouched." -ForegroundColor (Get-MessageColour muted)
    if ($_.Exception.Message -like "*import*") {
        Write-Host "        A half-registered '$Name' may be left behind:" -ForegroundColor (Get-MessageColour warning)
        Write-Host "        remove it with  .\wsl.ps1 unregister        (pick '$Name' in the list)" -ForegroundColor (Get-MessageColour hint)
    }
    exit 1
}

# What the setup did, on the screen - its own report, read here.
$Setup = $Report.Setup
if ($Setup.LookApplied) {
    Write-Host "  * Look             : font '$($Setup.Font)', colours '$($Setup.ColorScheme)', icon re-applied" -ForegroundColor (Get-MessageColour success)
} else {
    Write-Host "  * Look             : $($Setup.LookNote)" -ForegroundColor (Get-MessageColour warning)
}
if ($Setup.FontMissing) {
    Write-Host "                       Not installed on Windows: '$($Setup.Font)'." -ForegroundColor (Get-MessageColour warning)
    Write-Host "                       The prompt will show boxes until it is installed." -ForegroundColor (Get-MessageColour warning)
}
if ($Setup.DockerOutcome -eq "added") {
    Write-Host "  * Docker Desktop   : added, and restarted to pick it up" -ForegroundColor (Get-MessageColour success)
} elseif ($Setup.DockerOutcome -eq "added-late") {
    Write-Host "  * Docker Desktop   : added - restart it for it to notice" -ForegroundColor (Get-MessageColour hint)
} elseif ($Setup.DockerOutcome -eq "failed") {
    Write-Host "  * Docker Desktop   : could not be updated ($($Setup.DockerError))" -ForegroundColor (Get-MessageColour warning)
} elseif ($Setup.DockerOutcome -eq "not-added") {
    Write-Host "  * Docker Desktop   : not added - its settings can take it later" -ForegroundColor (Get-MessageColour muted)
}

Write-Host "============================================================" -ForegroundColor (Get-MessageColour success)
Write-Host "       '$Name' restored from an archive" -ForegroundColor (Get-MessageColour success)
Write-Host "============================================================" -ForegroundColor (Get-MessageColour success)
Write-Host ""
Write-Host "  * Install folder   : " -NoNewline; Write-Host "$($Report.Instance.Path)" -ForegroundColor (Get-MessageColour info)
Write-Host "  * From             : " -NoNewline; Write-Host "$($Chosen.Name)" -ForegroundColor (Get-MessageColour info)
Write-Host ""
Write-Host "  The archive is kept." -ForegroundColor (Get-MessageColour hint)
Write-Host "  Windows Terminal: restart it to see the icon, the font and the colour" -ForegroundColor (Get-MessageColour muted)
Write-Host "  scheme that came back with the archive." -ForegroundColor (Get-MessageColour muted)
Write-Host ""
