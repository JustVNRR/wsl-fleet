using module ..\..\BaseViewCli.psm1
using module ..\..\MenuCli.psm1
using module ..\..\..\..\Tools\Helpers.psm1

class CliSelectInstanceView : BaseViewCli {
    [object] AskOffered([object[]]$offered) {
        $Menu = [MenuCli]::new("Our Instances")
        foreach ($row in @($offered)) {
            $null = $Menu.Add([MenuItemCli]::new(
                ("{0,-30} {1,10}" -f $row.Name, (Format-Size ($row.Size))), $row.Name))
        }
        $Picked = $Menu.Prompt()
        if ($null -eq $Picked) { return "" }
        return $Picked.Value
    }

    [void] ShowNoInstances() {
        Write-Host ""
        Write-Host "[ABORT] No instance of this template is registered on this machine." -ForegroundColor $this.Colour("error")
        Write-Host "        Build one with  .\wsl-fleet.ps1 build" -ForegroundColor $this.Colour("hint")
    }

}
