using module ..\BaseViewCli.psm1
using module ..\MenuCli.psm1
using module ..\..\..\Tools\Helpers.psm1

class CliSettingsView : BaseViewCli {

    [object] PickAction([string]$title, [object[]]$actions) {
        $Menu = [MenuCli]::new($title)
        foreach ($item in @($actions)) { $null = $Menu.Add($item) }
        $Picked = $Menu.Prompt()
        if ($null -eq $Picked) { return $null }
        return $Picked
    }

    [object] PickPack([object[]]$packs) {
        $Menu = [MenuCli]::new("Packs Catalog")
        foreach ($pack in @($packs)) {
            $label = "{0,-20} {1,-10} {2}" -f "$($pack.Name)", "[$($pack.Family)]", "$($pack.Description)"
            $null = $Menu.Add([MenuItemCli]::new($label, $pack))
        }
        $Picked = $Menu.Prompt()
        if ($null -eq $Picked) { return $null }
        return $Picked.Value
    }

    [object] PickPackAction([string]$name) {
        $Menu = [MenuCli]::new("Pack '$name'")
        $null = $Menu.Add([MenuItemCli]::new("edit", "open the pack's folder", $null))
        $null = $Menu.Add([MenuItemCli]::new("duplicate", "duplicate it under a new name", $null))
        $null = $Menu.Add([MenuItemCli]::new("delete", "delete it from the catalog", $null))
        $Picked = $Menu.Prompt()
        if ($null -eq $Picked) { return $null }
        return $Picked
    }

    [string] AskName([string]$current) {
        return [string](Read-Host "Name of the copy of '$current' (Enter to cancel)").Trim()
    }

    [void] ShowOpening([string]$name) {
        Write-Host ""
        Write-Host "==> Opening the folder of '$name'" -ForegroundColor $this.Colour("info")
    }

    [void] ShowDuplicated([string]$name) {
        Write-Host ""
        Write-Host "==> '$name' created in the catalog" -ForegroundColor $this.Colour("success")
    }

    [void] ShowRemoved([string]$name) {
        Write-Host ""
        Write-Host "==> '$name' deleted from the catalog" -ForegroundColor $this.Colour("success")
    }

    [void] ShowDependents([string]$name, [string[]]$names) {
        Write-Host ""
        Write-Host "These packs depend on '$name':" -ForegroundColor $this.Colour("warning")
        foreach ($dependent in @($names)) {
            Write-Host "- $dependent" -ForegroundColor $this.Colour("warning")
        }
        Write-Host "Removing it may break them." -ForegroundColor $this.Colour("error")
    }

    [void] ShowNoPacks() {
        Write-Host ""
        Write-Host "[ABORT] The catalog holds no pack." -ForegroundColor $this.Colour("error")
        Write-Host "        A pack is a folder under assets\packs carrying a pack.conf." -ForegroundColor $this.Colour("hint")
    }
}
