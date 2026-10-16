using module ..\ActionResult.psm1
using module ..\BasePresenter.psm1
using module .\shared\SelectInstancePresenter.psm1
using module ..\..\Services\InstanceService.psm1
using module ..\..\Dtos\InstanceDto.psm1

class ManagePacksPresenter : BasePresenter {

    hidden [InstanceService]$Service
    [SelectInstancePresenter]$Picker

    ManagePacksPresenter([InstanceService]$service, [string]$viewsRoot, [string]$viewType) : base($viewsRoot, $viewType, "Instance") {
        $this.Service = $service
        $this.Picker = [SelectInstancePresenter]::new($viewsRoot, $viewType)
    }

    [ActionResult] Run([string]$target) {
        try {
            $rows = @($this.Service.GetAll())
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("ManagePacks : $($_.Exception.Message)")
        }

        $name = $this.Picker.Pick($target, $rows)
        if (-not $name) {
            if ($this.Picker.Miss -eq "none") { return [ActionResult]::Nok("ManagePacks : no instance") }
            return [ActionResult]::Ok("ManagePacks : cancelled")
        }

        $view = $this.GetView("ManagePacks")
        try {
            $packs = $this.Service.GetPacks($name)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("ManagePacks : $name - $($_.Exception.Message)")
        }

        $installed = @($packs.Installed)

        $rows = @()
        $checkedIndexes = @()
        $taken = @{}
        foreach ($pack in @($packs.Candidate)) {
            $rows += [PSCustomObject]@{ Name = "$($pack.Name)"; Description = "$($pack.Description)" }
            $taken["$($pack.Name)"] = $true
        }
        foreach ($removable in @($packs.Removable)) {
            if ($taken.ContainsKey("$removable")) { continue }
            $checkedIndexes += $rows.Count
            $rows += [PSCustomObject]@{ Name = "$removable"; Description = "" }
        }

        if ($rows.Count -eq 0) {
            $view.ShowNothingToChoose($name)
            return [ActionResult]::Ok("ManagePacks : cancelled")
        }

        $chosen = $view.AskPacks($name, $rows, $checkedIndexes)
        if ($null -eq $chosen) {
            $view.ShowCancelled("modified")
            return [ActionResult]::Ok("ManagePacks : cancelled")
        }
        $ticked = @($chosen | ForEach-Object { "$($_.Name)" })

        $toAdd = @($ticked | Where-Object { $installed -notcontains $_ })
        $toRemove = @(@($packs.Removable) | Where-Object { $ticked -notcontains "$_" })

        if ($toAdd.Count -eq 0 -and $toRemove.Count -eq 0) {
            $view.ShowNothingToDo($name)
            return [ActionResult]::Ok("ManagePacks : cancelled")
        }
        $view.ShowPlan($toAdd, $toRemove)

        $dto = [ManagePacksDto]::new()
        $dto.InstanceName = $name
        $dto.ToAdd = @($toAdd)
        $dto.ToRemove = @($toRemove)

        try {
            $response = $this.Service.ManagePacks($dto)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("ManagePacks : $($dto.InstanceName) - $($_.Exception.Message)")
        }
        $view.Show($response)
        return [ActionResult]::Ok("ManagePacks : $($dto.InstanceName)")
    }
}
