using module ..\BaseViewCli.psm1

class CliMigrateView : BaseViewCli {

    [object] AskTarget([string]$root) {
        Write-Host ""
        Write-Host -NoNewline "Move the fleet from '$root' to: "
        $answer = $this.AskLine("")
        if ($null -eq $answer) { return $null }
        return "$answer".Trim()
    }

    [void] ShowSameFolder() {
        Write-Host ""
        Write-Host "  That is the working folder - nothing to move." -ForegroundColor $this.Colour("warning")
    }

    [void] ShowTargetProblem([string]$problem) {
        Write-Host ""
        Write-Host "  $problem" -ForegroundColor $this.Colour("warning")
    }

    [void] ShowLead() {
        Write-Host ""
        Write-Host "==> Archiving the fleet" -ForegroundColor $this.Colour("info")
        Write-Host "  Instances are stopped one by one as they are archived." -ForegroundColor $this.Colour("muted")
    }

    [void] Show([object]$response) {
        Write-Host ""
        $names = @($response.Moved | Where-Object { $null -ne $_ })
        if ($names.Count) {
            Write-Host "==> Moved $($names -join ', ') and the archives to '$($response.Target)'." -ForegroundColor $this.Colour("success")
        } else {
            Write-Host "==> Moved the archives to '$($response.Target)'." -ForegroundColor $this.Colour("success")
        }
        Write-Host "    Restore them on the other side with  .\wsl-fleet.ps1 restore" -ForegroundColor $this.Colour("muted")
        Write-Host ""
    }
}
