using module ..\ActionResult.psm1
using module ..\BasePresenter.psm1
using module ..\..\Services\PackCatalogService.psm1
using module ..\..\Dtos\PackCatalogDto.psm1

class SettingsPresenter : BasePresenter {

    hidden [PackCatalogService]$Catalogue
    hidden [object[]]$Actions
    [string]$Miss = ""
    [string]$Error = ""

    SettingsPresenter([PackCatalogService]$catalogue, [string]$viewsRoot, [string]$viewType, [object[]]$actions) : base($viewsRoot, $viewType, "Fleet") {
        $this.Catalogue = $catalogue
        $this.Actions = $actions
    }

    [object] AskMenu() {
        $this.Miss = ""
        $this.Error = ""
        $view = $this.GetView("Settings")
        return $view.PickAction("Settings", $this.Actions)
    }

    [object] AskPack() {
        $this.Miss = ""
        $this.Error = ""
        $view = $this.GetView("Settings")
        try {
            $packs = @($this.Catalogue.GetAllPacks())
        } catch {
            $this.ShowFailure($_.Exception.Message)
            $this.Miss = "failure"
            $this.Error = $_.Exception.Message
            return $null
        }
        if ($packs.Count -eq 0) {
            $view.ShowNoPacks()
            $this.Miss = "none"
            return $null
        }
        $picked = $view.PickPack($packs)
        if (-not $picked) { $this.Miss = "cancelled"; return $null }
        return $picked
    }

    [object] AskPackAction([object]$pack) {
        $view = $this.GetView("Settings")
        return $view.PickPackAction("$($pack.Name)")
    }

    [object] Edit([object]$pack) {
        try {
            $this.Catalogue.OpenPackFolder("$($pack.Name)")
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Settings : $($_.Exception.Message)")
        }
        $this.GetView("Settings").ShowOpening("$($pack.Name)")
        return [ActionResult]::Ok("Settings : $($pack.Name)")
    }

    [object] Duplicate([object]$pack) {
        $view = $this.GetView("Settings")
        $newName = $view.AskName("$($pack.Name)")
        if (-not $newName) { return $null }
        try {
            $dto = [CreatePackDto]::new()
            $dto.SourceName = "$($pack.Name)"
            $dto.NewName = "$newName"
            $dto.Description = "$($pack.Description)"
            $null = $this.Catalogue.CreatePack($dto)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Settings : $($_.Exception.Message)")
        }
        $view.ShowDuplicated("$newName")
        return [ActionResult]::Ok("Settings : $newName")
    }

    [object] Delete([object]$pack) {
        $view = $this.GetView("Settings")
        $dependents = @($pack.Dependents)
        if ($dependents.Count -gt 0) { $view.ShowDependents("$($pack.Name)", $dependents) }
        if (-not $view.Confirm("Remove the pack '$($pack.Name)'?", $true)) { return $null }
        try {
            $this.Catalogue.DeletePack("$($pack.Name)")
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Settings : $($_.Exception.Message)")
        }
        $view.ShowRemoved("$($pack.Name)")
        return [ActionResult]::Ok("Settings : $($pack.Name)")
    }
}
