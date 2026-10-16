using module ..\BaseViewCli.psm1

class CliRestartView : BaseViewCli {

    [void] ShowStoppingWarning([string]$name) {
        Write-Host ""
        Write-Host "  '$name' will be stopped, then started again." -ForegroundColor $this.Colour("warning")
        Write-Host "  Save your work before proceeding." -ForegroundColor $this.Colour("warning")
    }

    [bool] AskRestart() {
        Write-Host ""
        return $this.Confirm("Restart it?", $false)
    }

    [void] ShowRestarting([string]$name) {
        Write-Host ""
        Write-Host "==> Restarting '$name'..." -ForegroundColor $this.Colour("info")
    }

    [void] Show([object]$response) {
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor $this.Colour("success")
        Write-Host "       '$($response.InstanceName)' is running again" -ForegroundColor $this.Colour("success")
        Write-Host "============================================================" -ForegroundColor $this.Colour("success")
        Write-Host ""
        Write-Host ""
    }
}
