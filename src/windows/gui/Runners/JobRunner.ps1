# The job the window's buttons run, for real: a CHILD PROCESS. A runspace of
# one's own was tried first, and it hangs - the engine's very first move reads
# wsl.exe, and a native program invoked in a runspace with no host never comes
# back on Windows (measured: the trail stopped at "imported", before "manager
# made"). A child pwsh HAS a host and runs wsl.exe like every other console;
# the trail file is how it reports. It runs as a child process, its arguments
# on the command line: verb, name, archive, module.

param([string]$Verb, [string]$Name, [string]$ArchiveFirst, [string]$Module)

$Log = Join-Path $env:TEMP "wsl-stack-gui-job.log"
function Write-Stamp($Message) {
    $null = Add-Content -LiteralPath $Log -Value "$(Get-Date -Format HH:mm:ss) $Message"
}

try {
    Write-Stamp "importing"
    Import-Module $Module -Force
    Write-Stamp "imported"
    $mgr = New-InstanceManager
    Write-Stamp "manager made"

    if ($Verb -eq "restore") {
        # No instance to find: the row was an archive. -ArchiveFirst carries
        # the archive folder here, and -Name the name the new instance takes.
        # Nobody asks here - the job is hidden - so the Docker word rides
        # false: the entry is left alone, and the ending says so.
        Write-Stamp "restoring"
        $r = $mgr.RestoreFromArchive($ArchiveFirst, $Name, $false)
        $docker = if ("$($r.Docker)" -eq "no") { " - Docker Desktop: not added (add it in its settings if needed)" } else { "" }
        Write-Stamp ("RESULT OK " + $Name + ": restored from '" + (Split-Path $ArchiveFirst -Leaf) + "'" + $docker)
    } elseif ($Verb -eq "delete") {
        # No instance to find here either: the archive's own folder goes.
        Write-Stamp "deleting the archive"
        $r = $mgr.DeleteArchive($Name)
        Write-Stamp ("RESULT OK " + $Name + ": archive deleted - " + [math]::Round($r.Freed / 1MB, 1) + " MB freed")
    } else {
        $inst = @($mgr.WslRegisteredInstances()) | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
        Write-Stamp "list read: $([bool]$inst)"
        if (-not $inst) { throw "'$Name' is not in our list any more." }

        if ($Verb -eq "archive") {
            # The instance's own gesture: it stops itself for the export and
            # comes back up - the permit below is the row's policy, it asks
            # nobody - and the report says whether it had to.
            Write-Stamp "archiving"
            $r = $mgr.Archive($inst, $ArchiveFirst, "tar.gz", $true)
            Write-Stamp ("RESULT OK " + $Name + ": archived as '" + $ArchiveFirst + "' (" + [math]::Round($r.Archive.Length / 1MB, 1) + " MB)")
        } elseif ($Verb -eq "duplicate") {
            # -ArchiveFirst carries the copy's name here. The engine's own
            # gesture: it refuses when the room is short, before anything
            # moves, and the instance stops itself for a consistent read and
            # comes back up when it went down for the copy - whatever the
            # outcome. The Docker word rides false: nobody asks in a hidden
            # job.
            Write-Stamp "duplicating"
            $r = $mgr.Duplicate($inst, $ArchiveFirst, $false)
            if ($r.Stopped) { Write-Stamp "stopped for a consistent read, started again" }
            $docker = if ("$($r.Docker)" -eq "no") { " - Docker Desktop: not added (add it in its settings if needed)" } else { "" }
            Write-Stamp ("RESULT OK " + $ArchiveFirst + ": duplicated from '" + $Name + "'" + $docker)
        } elseif ($Verb -eq "compact") {
            # The gate may have asked for the archive first: the copy is
            # written before the disk is touched, under the instance's own
            # name - the removal's convention - with the archive road's own
            # stop/start inside the export (the permit below is the row's
            # policy, it asks nobody).
            if ([bool]::Parse($ArchiveFirst)) {
                Write-Stamp "archiving first"
                $a = $mgr.Archive($inst, $Name, "tar.gz", $true)
                Write-Stamp ("RESULT OK " + $Name + ": archived as '" + $Name + "' (" + [math]::Round($a.Archive.Length / 1MB, 1) + " MB)")
            }
            Write-Stamp "compacting"
            $r = $mgr.Shrink($inst)
            Write-Stamp ("RESULT OK " + $Name + ": compacted - reclaimed " + [math]::Round($r.Freed / 1MB, 1) + " MB")
        } elseif ($Verb -eq "start") {
            Write-Stamp "starting"
            $inst.Start()
            Write-Stamp ("RESULT OK " + $Name + ": started")
        } elseif ($Verb -eq "stop") {
            Write-Stamp "stopping"
            $inst.Stop()
            Write-Stamp ("RESULT OK " + $Name + ": stopped")
        } else {
            Write-Stamp "removing"
            $r = $mgr.Unregister($inst, [bool]::Parse($ArchiveFirst))
            Write-Stamp ("RESULT OK " + $Name + ": removed - folder " + $r.Removed.FolderState)
        }
    }
    exit 0
} catch {
    Write-Stamp ("RESULT FAIL " + ($_.Exception.Message -replace "`r?`n", " "))
    exit 1
}
