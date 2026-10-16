using module ..\BaseViewCli.psm1
using module ..\..\..\Dtos\InstanceDto.psm1
using module ..\..\..\Tools\Helpers.psm1

class CliRestoreView : BaseViewCli {
    [void] ShowNoArchives() {
        Write-Host ""
        Write-Host "[ABORT] There are no archives." -ForegroundColor $this.Colour("error")
        Write-Host "        Nothing to restore:" -ForegroundColor $this.Colour("hint")
        Write-Host "            - Create one with  .\wsl-fleet.ps1 archive" -ForegroundColor $this.Colour("hint")
    }

    [object] AskArchive([object[]]$archives) {
        $Chosen = $this.AskList("Archives (most recent first):", @($archives), {
            param($Entry)
            "{0}  -  {1}" -f $Entry.Name, (Format-Size $Entry.Size)
        }, "")
        if (-not $Chosen) { return "" }
        return "$($Chosen.Name)"
    }

    [void] ShowRestoring([string]$archiveName) {
        Write-Host ""
        Write-Host "Restoring $archiveName as a new instance." -ForegroundColor $this.Colour("info")
    }

    [string] AskNewName() {
        return [string](Read-Host "Name of the new instance (Enter to cancel)").Trim()
    }

    [void] Show([object]$response) {
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor $this.Colour("success")
        Write-Host "       '$($response.InstanceName)' restored from an archive" -ForegroundColor $this.Colour("success")
        Write-Host "============================================================" -ForegroundColor $this.Colour("success")
        Write-Host ""
        Write-Host "  * From             : " -NoNewline; Write-Host "$($response.ArchiveName)" -ForegroundColor $this.Colour("info")
        Write-Host ""
        Write-Host "  The archive is kept." -ForegroundColor $this.Colour("hint")
        Write-Host "  Windows Terminal: restart it to see the icon, the font and the colour" -ForegroundColor $this.Colour("muted")
        Write-Host "  scheme that came back with the archive." -ForegroundColor $this.Colour("muted")
        Write-Host ""
    }
}
