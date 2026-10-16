using module ..\BaseViewCli.psm1

class CliRemoveView : BaseViewCli {

    [void] ShowDestructionGate([string]$name, [string]$lead) {
        [Console]::Beep(1000, 400)
        Write-Host ""
        $this.ShowDangerBanner("DANGER: TOTAL DATA LOSS IMMINENT")
        Write-Host ""
        Write-Host "  $lead" -ForegroundColor $this.Colour("error")
        Write-Host ""
        Write-Host "  Proceeding will PERMANENTLY DESTROY this distribution:" -ForegroundColor $this.Colour("warning")
        Write-Host "    - Executing: wsl --unregister $name" -ForegroundColor $this.Colour("muted")
        Write-Host "    - IRREVERSIBLE DELETION of the virtual disk (VHDX)" -ForegroundColor $this.Colour("muted")
        Write-Host "    - TOTAL LOSS of projects, SSH keys, and all files in /home" -ForegroundColor $this.Colour("muted")
        Write-Host ""
        Write-Host "  THIS OPERATION CANNOT BE UNDONE." -ForegroundColor $this.Colour("error")
        Write-Host ""
        Write-Host " ----------------------------------------------------------------------" -ForegroundColor $this.Colour("muted")
        Write-Host " Press ENTER to abort immediately." -ForegroundColor $this.Colour("hint")
        Write-Host " To confirm DESTRUCTION, type the name of the distribution:" -ForegroundColor $this.Colour("hint")
    }

    [object] AskTypedName() {
        return $this.AskLine(" Confirm")
    }

    [void] ShowGateClose() {
        Write-Host " ----------------------------------------------------------------------" -ForegroundColor $this.Colour("muted")
        Write-Host ""
    }

    [void] ShowGateOpened() {
        Write-Host ""
    }

    [void] ShowGateRefused() {
        Write-Host "[ABORT] Operation cancelled. No data was modified." -ForegroundColor $this.Colour("warning")
    }

    [void] ShowReplacingArchive([string]$name) {
        Write-Host "  '$name' exists: replacing its archive." -ForegroundColor $this.Colour("warning")
    }

    [void] ShowRemovingSteps() {
        Write-Host "==> Stopping the distro processes..." -ForegroundColor $this.Colour("info")
        Write-Host "==> Unregistering the distro..." -ForegroundColor $this.Colour("info")
    }

    [void] Show() {
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor $this.Colour("success")
        Write-Host "                Wsl Fleet Instance Removed!                 " -ForegroundColor $this.Colour("success")
        Write-Host "============================================================" -ForegroundColor $this.Colour("success")
        Write-Host ""
        Write-Host ""
        Write-Host " Restart Windows Terminal to refresh the profile list."
        Write-Host ""
    }
}
