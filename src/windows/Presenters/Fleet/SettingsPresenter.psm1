using module ..\ActionResult.psm1
using module ..\BasePresenter.psm1
using module ..\..\Services\PackCatalogService.psm1
using module ..\..\Dtos\PackCatalogDto.psm1

class SettingsPresenter : BasePresenter {

    hidden [PackCatalogService]$Catalogue
    hidden [object[]]$Actions

    SettingsPresenter([PackCatalogService]$catalogue, [string]$viewsRoot, [string]$viewType, [object[]]$actions) : base($viewsRoot, $viewType, "Fleet") {
        $this.Catalogue = $catalogue
        $this.Actions = $actions
    }

    [ActionResult] Run([hashtable]$Presenters) {
        $view = $this.GetView("Settings")
        $picked = $view.PickAction("Settings", $this.Actions)
        if (-not $picked) { return [ActionResult]::Ok("Settings : cancelled") }

        if ("$($picked.Key)" -ne "availables packs") {
            return (& $picked.Action "" $Presenters)
        }

        try {
            $packs = @($this.Catalogue.GetAllPacks())
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Settings : $($_.Exception.Message)")
        }
        if ($packs.Count -eq 0) {
            $view.ShowNoPacks()
            return [ActionResult]::Nok("Settings : no packs")
        }

        $pack = $view.PickPack($packs)
        if (-not $pack) { return [ActionResult]::Ok("Settings : cancelled") }

        $choice = $view.PickPackAction("$($pack.Name)")
        if (-not $choice) { return [ActionResult]::Ok("Settings : cancelled") }

        switch ("$($choice.Key)") {
            "edit" {
                try {
                    $this.Catalogue.OpenPackFolder("$($pack.Name)")
                } catch {
                    $this.ShowFailure($_.Exception.Message)
                    return [ActionResult]::Nok("Settings : $($_.Exception.Message)")
                }
                $view.ShowOpening("$($pack.Name)")
                return [ActionResult]::Ok("Settings : $($pack.Name)")
            }

            "duplicate" {
                $newName = $view.AskName("$($pack.Name)")
                if (-not $newName) {
                    $view.ShowCancelled("created")
                    return [ActionResult]::Ok("Settings : cancelled")
                }
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

            "delete" {
                $dependents = @($pack.Dependents)
                if ($dependents.Count -gt 0) { $view.ShowDependents("$($pack.Name)", $dependents) }
                if (-not $view.Confirm("Remove the pack '$($pack.Name)'?", $true)) {
                    $view.ShowCancelled("removed")
                    return [ActionResult]::Ok("Settings : cancelled")
                }
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

        return [ActionResult]::Ok("Settings : $($pack.Name)")
    }
}
