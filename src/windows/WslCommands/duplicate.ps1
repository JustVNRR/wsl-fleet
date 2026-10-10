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
    # Controllers\Duplicate.ps1) renders them: the source, the copy's name,
    # and the Docker word. This file never asks.
    [object]$Form
)

$ErrorActionPreference = "Stop"

$Source = $Form.Instance
$SourceDistro = $Source.Name
$NewDistroName = $Form.Name
$AddDocker = $Form.AddDocker

# 1-2. What it costs, measured by the engine: the copy reads the instance into
# an archive and unpacks it into the new folder, both at the same time - twice
# the disk is the peak the engine's own copy refuses past. The archive route
# rather than a raw disk copy (`--format vhd`): a vhd export is refused with
# ERROR_SHARING_VIOLATION while the WSL virtual machine is up - `--terminate`
# does not release it, only a full `--shutdown` does, and that stops every
# other instance. The copy pays the compression instead.
$Cost = $Manager.DuplicationCost($Source, $NewDistroName)

Write-Host ""
Write-Host "==> Duplicating '$SourceDistro' into '$NewDistroName'" -ForegroundColor (Get-MessageColour info)
Write-Host "  * Source disk      : $(Format-Size $Cost.DiskBytes)" -ForegroundColor (Get-MessageColour muted)
Write-Host "  * Needed on $($Cost.DriveLetter)`:      : $(Format-Size $Cost.NeededBytes) (archive + copy at peak)" -ForegroundColor (Get-MessageColour muted)
Write-Host "  * Free on $($Cost.DriveLetter)`:        : $(Format-Size $Cost.FreeBytes)" -ForegroundColor (Get-MessageColour muted)
Write-Host "  * Install folder   : $($Cost.InstallPath)" -ForegroundColor (Get-MessageColour muted)

# 3. Copy: the source is only read. The room is the engine's own refusal - it
# comes back through the catch below - and the stopping and the coming back up
# are the instance's own. The temporary image is removed by the engine's own
# copy, in all cases - it is worth twice the disk, and leaving it would eat
# the room just checked for.

try {
    Write-Host "==> 1. Reading the source (the source itself is not modified)..." -ForegroundColor (Get-MessageColour info)
    Write-Host "==> 2. Registering '$NewDistroName' from it..." -ForegroundColor (Get-MessageColour info)
    $Report = $Manager.Duplicate($Source, $NewDistroName, $AddDocker)
} catch {
    Write-Host ""
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor (Get-MessageColour error)
    Write-Host "        The source was not modified." -ForegroundColor (Get-MessageColour muted)
    if ($_.Exception.Message -like "*import*") {
        Write-Host "        A half-registered '$NewDistroName' may be left behind:" -ForegroundColor (Get-MessageColour warning)
        Write-Host "        remove it with  .\wsl.ps1 unregister        (pick '$NewDistroName' in the list)" -ForegroundColor (Get-MessageColour hint)
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

Write-Host ""
Write-Host "============================================================" -ForegroundColor (Get-MessageColour success)
Write-Host "       '$NewDistroName' is a copy of '$SourceDistro'" -ForegroundColor (Get-MessageColour success)
Write-Host "============================================================" -ForegroundColor (Get-MessageColour success)
Write-Host ""
Write-Host "  * Install folder   : " -NoNewline; Write-Host "$($Report.InstallPath)" -ForegroundColor (Get-MessageColour info)
Write-Host "  * Copy on disk     : " -NoNewline; Write-Host "$(Format-Size $Report.CopyBytes)" -ForegroundColor (Get-MessageColour info)
Write-Host "  * WSL version      : " -NoNewline; Write-Host "$($Source.Version)" -ForegroundColor (Get-MessageColour info)
Write-Host ""
Write-Host "  Windows Terminal: the copy gets a profile of its own, with the icon," -ForegroundColor (Get-MessageColour muted)
Write-Host "  the font and the colours of the source. Restart Terminal to see it." -ForegroundColor (Get-MessageColour muted)
Write-Host ""

# Left the way it was found - the copy put the source back itself: found
# running, running again; the report says whether it had to.
if ($Report.Stopped) {
    Write-Host "'$SourceDistro' is running again." -ForegroundColor (Get-MessageColour success)
} else {
    Write-Host "'$SourceDistro' is left stopped." -ForegroundColor (Get-MessageColour muted)
}
Write-Host ""
