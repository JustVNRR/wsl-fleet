using module ..\BaseViewCli.psm1

class CliErrorView : BaseViewCli {

    [void] Show([string]$failure) {
        Write-Host ""
        Write-Host "[FAIL] $failure" -ForegroundColor $this.Colour("error")
        Write-Host ""
    }
}
