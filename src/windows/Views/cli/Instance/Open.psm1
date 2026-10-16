using module ..\BaseViewCli.psm1

class CliOpenView : BaseViewCli {

    [void] ShowOpening([string]$name) {
        Write-Host ""
        Write-Host "==> Opening a shell in '$name'..." -ForegroundColor $this.Colour("info")
    }

    [void] Show([object]$response) {
    }
}
