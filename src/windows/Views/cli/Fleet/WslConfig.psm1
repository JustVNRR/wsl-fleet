using module ..\BaseViewCli.psm1

class CliWslConfigView : BaseViewCli {
    [void] ShowLead() {
        Write-Host ""
        Write-Host "==> Opening .wslconfig" -ForegroundColor $this.Colour("info")
    }

    [void] Show([object]$response) {
        if ($response.Created) {
            Write-Host "  * .wslconfig : " -NoNewline
            Write-Host "file created" -ForegroundColor $this.Colour("success")
        } else {
            Write-Host "  * .wslconfig : " -NoNewline
            Write-Host "$($response.Path)" -ForegroundColor $this.Colour("info")
        }
    }
}
