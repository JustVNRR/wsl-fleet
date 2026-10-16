using module ..\BaseViewCli.psm1
using module ..\..\..\Dtos\InstanceDto.psm1

class CliArchiveView : BaseViewCli {

    [void] ShowStopWarning([string]$name) {
        Write-Host ""
        Write-Host "  If '$name' is running, this will stop it: an archive reads a still disk." -ForegroundColor $this.Colour("warning")
        Write-Host "  Save what you have open in there - stopping it loses anything unsaved." -ForegroundColor $this.Colour("warning")
    }

    [void] ShowReplacing([string]$archiveName) {
        Write-Host "  '$archiveName' exists: replacing it." -ForegroundColor $this.Colour("warning")
    }

    [void] ShowBackingUp([string]$name) {
        Write-Host ""
        Write-Host "==> Backing up '$name'" -ForegroundColor $this.Colour("info")
    }

    [void] Show([object]$response) {
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor $this.Colour("success")
        Write-Host "       Backup of '$($response.InstanceName)' written" -ForegroundColor $this.Colour("success")
        Write-Host "============================================================" -ForegroundColor $this.Colour("success")
        Write-Host ""
        Write-Host "  * Look             : font '$($response.LookFont)', colours '$($response.LookColourScheme)'" -ForegroundColor $this.Colour("muted")
        Write-Host "  * Docker Desktop   : $(if ($response.Docker -eq "yes") { "knows this instance" } elseif ($response.Docker -eq "no") { "does not know it" } else { "not installed, or unreadable" })" -ForegroundColor $this.Colour("muted")
        Write-Host "  * Archive          : " -NoNewline; Write-Host "$($response.ArchiveDir)" -ForegroundColor $this.Colour("info")
        Write-Host "  * Tar              : " -NoNewline; Write-Host "$(Split-Path -Leaf "$($response.Tar)")" -ForegroundColor $this.Colour("info")
        Write-Host ""
        Write-Host "------------------------------------------------------------" -ForegroundColor $this.Colour("muted")
        Write-Host "To restore it as a new instance:" -ForegroundColor $this.Colour("hint")
        Write-Host "  .\wsl-fleet.ps1 restore        (it lists the archives, this one included)" -ForegroundColor $this.Colour("hint")
        Write-Host "------------------------------------------------------------" -ForegroundColor $this.Colour("muted")
        Write-Host ""
        if ($response.Stopped) {
            Write-Host "'$($response.InstanceName)' is running again." -ForegroundColor $this.Colour("success")
        } else {
            Write-Host "'$($response.InstanceName)' is left stopped." -ForegroundColor $this.Colour("muted")
        }
        Write-Host ""
    }
}
