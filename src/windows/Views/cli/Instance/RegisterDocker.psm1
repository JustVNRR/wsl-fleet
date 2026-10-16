using module ..\BaseViewCli.psm1

class CliRegisterDockerView : BaseViewCli {

    [void] ShowNoCandidates() {
        Write-Host ""
        Write-Host "[ABORT] No instance is unregistered with Docker Desktop." -ForegroundColor $this.Colour("error")
        Write-Host "        Nothing was modified." -ForegroundColor $this.Colour("hint")
    }

    [void] ShowSettingsUnreadable() {
        Write-Host ""
        Write-Host "[ABORT] Docker Desktop's settings cannot be read." -ForegroundColor $this.Colour("error")
        Write-Host "        Start Docker Desktop once, then try again - nothing was modified." -ForegroundColor $this.Colour("hint")
    }

    [void] ShowAlreadyRegistered([string]$name) {
        Write-Host ""
        Write-Host "[ABORT] '$name' is already registered with Docker Desktop." -ForegroundColor $this.Colour("error")
        Write-Host "        Nothing was modified." -ForegroundColor $this.Colour("hint")
    }

    [bool] AskRegister([string]$name) {
        Write-Host ""
        return $this.Confirm("Register '$name' with Docker Desktop?", $false)
    }

    [bool] AskRestartDocker() {
        Write-Host ""
        return $this.Confirm("Restart Docker Desktop now? Running containers will stop.", $false)
    }

    [void] Show([object]$response) {
        Write-Host ""
        Write-Host "       '$($response.InstanceName)' is registered with Docker Desktop." -ForegroundColor $this.Colour("success")
        switch ("$($response.Restart)") {
            "restarted" { Write-Host "       Docker Desktop was restarted." -ForegroundColor $this.Colour("success") }
            "started"   { Write-Host "       Docker Desktop was started." -ForegroundColor $this.Colour("success") }
            "pending"   { Write-Host "       Docker Desktop would not restart - it will be seen at its next start." -ForegroundColor $this.Colour("warning") }
            default     { Write-Host "       It will be seen at Docker Desktop's next start." -ForegroundColor $this.Colour("muted") }
        }
        Write-Host ""
    }
}
