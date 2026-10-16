using module ..\BaseViewCli.psm1
using module ..\MenuCli.psm1
using module ..\..\..\Tools\Helpers.psm1

class CliBrowseView : BaseViewCli {

    [object] PickInstance([object[]]$rows, [object[]]$orphans, [string[]]$running) {
        $this.ShowOrphans($orphans)
        $Menu = [MenuCli]::new("Our Instances")
        foreach ($row in @($rows)) {
            $state = if (@($running) -contains "$($row.Name)") { "running" } else { "stopped" }
            $label = "{0,-30} {1,-8} {2,10}" -f "$($row.Name)", $state, (Format-Size ([double]$row.Size))
            $null = $Menu.Add([MenuItemCli]::new($label, $row))
        }
        $Picked = $Menu.Prompt()
        if ($null -eq $Picked) { return $null }
        return $Picked.Value
    }

    [object] PickArchive([object[]]$archives) {
        $Menu = [MenuCli]::new("Our Archives")
        foreach ($row in @($archives)) {
            $label = "{0,-30} {1,10}" -f "$($row.Name)", (Format-Size ([double]$row.Size))
            $null = $Menu.Add([MenuItemCli]::new($label, $row))
        }
        $Picked = $Menu.Prompt()
        if ($null -eq $Picked) { return $null }
        return $Picked.Value
    }

    [object] PickAction([string]$title, [object[]]$actions) {
        $Menu = [MenuCli]::new($title)
        foreach ($item in @($actions)) { $null = $Menu.Add($item) }
        $Picked = $Menu.Prompt()
        if ($null -eq $Picked) { return $null }
        return $Picked
    }

    hidden [void] ShowOrphans([object[]]$orphans) {
        if (@($orphans).Count -eq 0) { return }
        Write-Host ""
        Write-Host "Folders left behind by an instance that is gone:" -ForegroundColor $this.Colour("hint")
        foreach ($row in @($orphans)) {
            Write-Host ("      {0,-30} {1,10}  {2}" -f "$($row.Name)", (Format-Size ([double]$row.Size)), "$($row.Path)") -ForegroundColor $this.Colour("hint")
        }
        Write-Host "      No instance claims them, and no command removes them: delete them by hand." -ForegroundColor $this.Colour("muted")
    }

    [void] ShowNoInstances([object[]]$orphans) {
        $this.ShowOrphans($orphans)
        Write-Host ""
        Write-Host "[ABORT] No instance of this template is registered on this machine." -ForegroundColor $this.Colour("error")
        Write-Host "        Build one with  .\wsl-fleet.ps1 build" -ForegroundColor $this.Colour("hint")
    }

    [void] ShowNoArchives() {
        Write-Host ""
        Write-Host "[ABORT] There are no archives." -ForegroundColor $this.Colour("error")
        Write-Host "        Create one with  .\wsl-fleet.ps1 archive" -ForegroundColor $this.Colour("hint")
    }
}
