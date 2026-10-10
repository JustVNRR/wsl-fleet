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

# No parameter, and no question either: this command only reads, so it can be
# run at any moment. Its exit code says whether there was anything to show - 1
# when there is none, like the other commands' lists.

$ErrorActionPreference = "Stop"

# 1. Our instances, running or stopped, by name like every list in this family -
# and, with them, the archives on disk and the folders left behind: the engine's
# List() answers all three at once, what runs included (its batched question,
# asked once). Nothing at all is the only refusal.
$Report = $Manager.List()
$All = @($Report.Instances)
$Archives = @($Report.Archives)
$Forgotten = @($Report.Forgotten)

if ($All.Count -eq 0 -and $Archives.Count -eq 0 -and $Forgotten.Count -eq 0) {
    Write-Host ""
    Write-Host "[ABORT] No instance of this template is registered on this machine." -ForegroundColor (Get-MessageColour error)
    Write-Host "        Build one with  .\wsl.ps1 build" -ForegroundColor (Get-MessageColour hint)
    exit 1
}

if ($All.Count -gt 0) {
    Write-Host ""
    Write-Host "Instances of this template:" -ForegroundColor (Get-MessageColour info)
    for ($Index = 0; $Index -lt $All.Count; $Index++) {
        $Entry = $All[$Index]
        $State = if ($Entry.State -eq [WslState]::Running) { "running" } else { "stopped" }
        Write-Host ("  {0,2}.  {1,-30} {2,-8} {3,10}  {4}" -f ($Index + 1), $Entry.Name, $State,
            (Format-Size ($Entry.DiskBytes())), $Entry.Path)
    }
}

# 2. The archives: everything in that folder was written by archive.ps1, so
# there is nothing to tell apart.
if ($Archives.Count -gt 0) {
    Write-Host ""
    Write-Host "Archives (most recent first):" -ForegroundColor (Get-MessageColour info)
    foreach ($Entry in $Archives) {
        Write-Host ("      {0,-30} {1,10}  {2}  {3}" -f $Entry.Name, (Format-Size $Entry.DiskBytes()),
            $Entry.ArchivedOn().ToString("yyyy-MM-dd HH:mm"), $Entry.ArchivePath)
    }
}

# 3. Marked folders that no instance claims - what an interrupted removal, or
# an outside `wsl --unregister`, leaves behind. The one place they show.
if ($Forgotten.Count -gt 0) {
    Write-Host ""
    Write-Host "Folders left behind by an instance that is gone:" -ForegroundColor (Get-MessageColour hint)
    foreach ($Row in $Forgotten) {
        Write-Host ("      {0,-30} {1,10}  {2}" -f $Row.Name,
            (Format-Size $Row.Bytes), $Row.Path) -ForegroundColor (Get-MessageColour hint)
    }
    Write-Host "      No instance claims them, and no command removes them: delete them by hand." -ForegroundColor (Get-MessageColour muted)
}

Write-Host ""
