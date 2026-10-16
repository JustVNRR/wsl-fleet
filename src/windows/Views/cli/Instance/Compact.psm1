using module ..\BaseViewCli.psm1
using module ..\..\..\Tools\Helpers.psm1

class CliCompactView : BaseViewCli {

    [void] ShowBeforeQuestions() {
        Write-Host ""
    }

    [void] ShowNoArchive() {
        Write-Host "  No archive - compacting on its own." -ForegroundColor $this.Colour("muted")
    }

    [void] ShowReplacingArchive([string]$name) {
        Write-Host "  '$name' exists: replacing its archive." -ForegroundColor $this.Colour("warning")
    }

    [void] ShowCompacting([string]$name, [bool]$archiveFirst) {
        Write-Host ""
        Write-Host "  WARNING: THE INSTANCE WILL BE STOPPED." -ForegroundColor $this.Colour("warning")
        Write-Host "  Make sure nothing is running inside." -ForegroundColor $this.Colour("muted")
        Write-Host ""
        Write-Host "==> Reclaiming space in '$name'" -ForegroundColor $this.Colour("info")
        if ($archiveFirst) {
            Write-Host "==> Creating safety archive..." -ForegroundColor $this.Colour("info")
        }
        Write-Host "==> Compacting the virtual disk..." -ForegroundColor $this.Colour("info")
    }

    [void] Show([object]$response) {
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor $this.Colour("success")
        Write-Host "       '$($response.InstanceName)' compacted" -ForegroundColor $this.Colour("success")
        Write-Host "============================================================" -ForegroundColor $this.Colour("success")
        Write-Host ""
        Write-Host "  * Disk file        : " -NoNewline
        Write-Host "$(Format-Size $response.SizeBefore) -> $(Format-Size $response.SizeAfter)" -ForegroundColor $this.Colour("info")
        if ($response.Gained -gt 0) {
            Write-Host "  * Reclaimed        : " -NoNewline
            Write-Host "$(Format-Size $response.Gained)" -ForegroundColor $this.Colour("success")
        } else {
            Write-Host "  * Reclaimed        : " -NoNewline
            Write-Host "nothing - the disk held no space to give back" -ForegroundColor $this.Colour("muted")
        }
        if ($response.Archived) {
            Write-Host "  * Safety archive   : " -NoNewline; Write-Host "taken before the compact" -ForegroundColor $this.Colour("success")
        }
        if ($response.Restarted) {
            Write-Host "'$($response.InstanceName)' is running again." -ForegroundColor $this.Colour("success")
        }
        Write-Host ""
    }
}
