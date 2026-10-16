using module ..\BaseViewCli.psm1

class CliDeleteArchiveView : BaseViewCli {

    [void] ShowNoName() {
        Write-Host ""
        Write-Host "[ABORT] No archive name was given." -ForegroundColor $this.Colour("error")
        Write-Host "        The archives are listed by  .\wsl-fleet.ps1 list" -ForegroundColor $this.Colour("hint")
        Write-Host "        Then:  .\wsl-fleet.ps1 delete_archive <name>" -ForegroundColor $this.Colour("hint")
    }

    [void] ShowDeleting([string]$name) {
        Write-Host ""
        Write-Host "==> Deleting the archive '$name'..." -ForegroundColor $this.Colour("info")
    }

    [void] Show([object]$response) {
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor $this.Colour("success")
        Write-Host "       Archive '$($response.ArchiveName)' deleted" -ForegroundColor $this.Colour("success")
        Write-Host "============================================================" -ForegroundColor $this.Colour("success")
        Write-Host ""
        Write-Host "  * Gone for good - no trash, no copy kept." -ForegroundColor $this.Colour("muted")
        Write-Host ""
    }
}
