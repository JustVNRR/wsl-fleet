using module ..\BaseViewCli.psm1

class CliRemovePackView : BaseViewCli {

    [void] ShowNoPacks([string]$name) {
        Write-Host ""
        Write-Host "[OK] '$name' carries no pack - there is nothing to remove." -ForegroundColor $this.Colour("success")
    }

    [void] ShowNoRemovable([string]$name) {
        Write-Host ""
        Write-Host "[OK] '$name' carries no pack you choose or remove by hand." -ForegroundColor $this.Colour("success")
    }

    [object] AskPack([string]$name, [object[]]$offered) {
        $PackName = $this.AskList("Packs installed in '$name':", @($offered), {
            param($Entry)
            [string]$Entry
        }, "")
        if (-not $PackName) { return "" }
        return "$PackName"
    }

    [bool] AskRemoval([string]$packName) {
        Write-Host ""
        return $this.Confirm("Remove '$packName'?", $false)
    }

    [void] ShowRemoving([string]$packName, [string]$name) {
        Write-Host ""
        Write-Host "==> Removing '$packName' from '$name'..." -ForegroundColor $this.Colour("info")
    }

    [void] Show([object]$response) {
        if ($response.Outcome -eq "conflict") {
            Write-Host ""
            Write-Host ("[ABORT] A pack cannot be removed while these still require it: {0}." -f ($response.Dependents -join " and ")) -ForegroundColor $this.Colour("error")
            Write-Host ("        Take {0} out first, or leave this one where it is." -f ($response.Dependents -join " and ")) -ForegroundColor $this.Colour("hint")
            Write-Host ""
            return
        }

        if ($response.Outcome -eq "self-failed") {
            Write-Host ""
            Write-Host "[FAIL] The pack could not remove itself (exit code $($response.ExitCode))." -ForegroundColor $this.Colour("error")
            Write-Host "       Nothing was deleted: it is still installed in '$($response.InstanceName)'." -ForegroundColor $this.Colour("hint")
            Write-Host ""
            return
        }

        if ($response.Outcome -eq "folder-failed") {
            Write-Host ""
            Write-Host "[FAIL] The pack's folder could not be deleted (exit code $($response.ExitCode))." -ForegroundColor $this.Colour("error")
            Write-Host "       It is out of the gmake menu, but its files are still in '$($response.InstanceName)'." -ForegroundColor $this.Colour("warning")
            Write-Host ""
            return
        }

        Write-Host ""
        Write-Host "The pack was successfully uninstalled." -ForegroundColor $this.Colour("success")
    }
}
