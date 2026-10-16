using module ..\BaseViewCli.psm1

class CliDuplicateView : BaseViewCli {

    [object] AskCopyName() {
        $answer = $this.AskLine("Name of the copy")
        if ($null -eq $answer) { return $null }
        return "$answer".Trim()
    }

    [void] ShowNameHint() {
        Write-Host "  Letters, digits, '.', '_' and '-' only." -ForegroundColor $this.Colour("hint")
    }

    [void] ShowDiskWarning([string]$source) {
        Write-Host ""
        Write-Host "  If '$source' is running, this will stop it." -ForegroundColor $this.Colour("warning")
        Write-Host "  Save your work before proceeding." -ForegroundColor $this.Colour("warning")
    }

    [void] ShowDuplicating([string]$source, [string]$copy) {
        Write-Host ""
        Write-Host "==> Duplicating '$source' into '$copy'" -ForegroundColor $this.Colour("info")
        Write-Host "==> 1. Reading the source (the source itself is not modified)..." -ForegroundColor $this.Colour("info")
        Write-Host "==> 2. Registering '$copy' from it..." -ForegroundColor $this.Colour("info")
    }

    [void] Show([object]$response) {
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor $this.Colour("success")
        Write-Host "       '$($response.CopyName)' is a copy of '$($response.SourceName)'" -ForegroundColor $this.Colour("success")
        Write-Host "============================================================" -ForegroundColor $this.Colour("success")
        Write-Host ""
        Write-Host "  Windows Terminal: the copy gets a profile of its own, with the icon," -ForegroundColor $this.Colour("muted")
        Write-Host "  the font and the colours of the source. Restart Terminal to see it." -ForegroundColor $this.Colour("muted")
        Write-Host ""
    }
}
