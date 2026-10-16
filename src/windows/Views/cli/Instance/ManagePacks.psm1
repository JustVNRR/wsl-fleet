using module ..\BaseViewCli.psm1

class CliManagePacksView : BaseViewCli {

    [void] ShowNothingToChoose([string]$name) {
        Write-Host ""
        Write-Host "[OK] '$name' carries nothing to choose and this repository offers nothing to add." -ForegroundColor $this.Colour("success")
    }

    [object[]] AskPacks([string]$name, [object[]]$rows, [int[]]$checkedIndexes) {
        return $this.AskChecklist("Packs for '$name'", @($rows), {
            param($Row)
            "{0,-12} {1}" -f $Row.Name, $Row.Description
        }, @($checkedIndexes), "")
    }

    [void] ShowNothingToDo([string]$name) {
        Write-Host ""
        Write-Host "[OK] Nothing to do: '$name' already has exactly that." -ForegroundColor $this.Colour("success")
    }

    [void] ShowPlan([string[]]$toAdd, [string[]]$toRemove) {
        Write-Host ""
        if (@($toAdd).Count -gt 0) {
            Write-Host "==> Installing: $($toAdd -join ', ')" -ForegroundColor $this.Colour("info")
        }
        if (@($toRemove).Count -gt 0) {
            Write-Host "==> Removing: $($toRemove -join ', ')" -ForegroundColor $this.Colour("info")
        }
    }

    [void] Show([object]$response) {
        if ($response.Outcome -eq "failed") {
            Write-Host ""
            Write-Host "[FAIL] '$($response.Failed -join ', ')' did not complete (exit code $($response.ExitCode))." -ForegroundColor $this.Colour("error")
            Write-Host "       The packs already applied stay - run this again to finish." -ForegroundColor $this.Colour("hint")
            Write-Host ""
            return
        }

        Write-Host ""
        if ($response.Installed.Count -gt 0) {
            Write-Host "==> $($response.Installed -join ', ') successfully installed on '$($response.InstanceName)'" -ForegroundColor $this.Colour("success")
            Write-Host "    Open a shell in it to use them:  .\wsl-fleet.ps1 shell" -ForegroundColor $this.Colour("muted")
        }
        if ($response.Removed.Count -gt 0) {
            Write-Host "==> $($response.Removed -join ', ') successfully removed from '$($response.InstanceName)'" -ForegroundColor $this.Colour("success")
        }
    }
}
