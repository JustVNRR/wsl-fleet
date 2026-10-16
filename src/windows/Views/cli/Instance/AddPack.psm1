using module ..\BaseViewCli.psm1

class CliAddPackView : BaseViewCli {

    [void] ShowAlreadyComplete([string]$name) {
        Write-Host ""
        Write-Host "[OK] '$name' already has every pack this repository offers." -ForegroundColor $this.Colour("success")
    }

    [void] ShowAlreadyIn([string]$name, [object[]]$installed) {
        Write-Host ""
        Write-Host ("       Already in '$name': {0}" -f ($installed -join ", ")) -ForegroundColor $this.Colour("muted")
    }

    [object] AskPack([string]$name, [object[]]$candidates) {
        $Pack = $this.AskList("Packs available for '$name':", @($candidates), {
            param($Entry)
            "{0,-12} {1}" -f $Entry.Name, $Entry.Description
        }, "")
        if (-not $Pack) { return "" }
        return $Pack
    }

    [void] Show([object]$response) {
        if ($response.Outcome -eq "copy-failed") {
            Write-Host "[ABORT] Could not copy the pack's files into '$($response.InstanceName)' (exit code $($response.ExitCode))." -ForegroundColor $this.Colour("error")
            Write-Host "        The message above says what refused: the instance, or Windows." -ForegroundColor $this.Colour("hint")
            Write-Host ""
            return
        }

        if ($response.Outcome -eq "failed") {
            Write-Host ""
            Write-Host "[FAIL] The installation did not complete (exit code $($response.ExitCode))." -ForegroundColor $this.Colour("error")
            Write-Host "       The pack's files were removed." -ForegroundColor $this.Colour("hint")
            Write-Host "       Whatever the install had already put in place is still there - run this again to finish." -ForegroundColor $this.Colour("hint")
            Write-Host ""
            return
        }

        Write-Host ""
        if ($response.Installed.Count -gt 0) {
            Write-Host "       Installed: $($response.Installed -join ', ')" -ForegroundColor $this.Colour("success")
        }
        if ($response.Skipped.Count -gt 0) {
            Write-Host "       Already there: $($response.Skipped -join ', ')" -ForegroundColor $this.Colour("muted")
        }
    }
}
