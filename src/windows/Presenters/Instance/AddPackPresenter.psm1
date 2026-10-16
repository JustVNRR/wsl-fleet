using module ..\ActionResult.psm1
using module ..\BasePresenter.psm1
using module .\shared\SelectInstancePresenter.psm1
using module ..\..\Services\InstanceService.psm1
using module ..\..\Dtos\InstanceDto.psm1

class AddPackPresenter : BasePresenter {
    hidden [InstanceService]$Service

    [SelectInstancePresenter]$Picker

    AddPackPresenter([InstanceService]$service, [string]$viewsRoot, [string]$viewType) : base($viewsRoot, $viewType, "Instance") {
        $this.Service = $service
        $this.Picker = [SelectInstancePresenter]::new($viewsRoot, $viewType)
    }

    [ActionResult] Run([string]$target) {
        try {
            $rows = @($this.Service.GetAll())
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("AddPack : $($_.Exception.Message)")
        }

        $name = $this.Picker.Pick($target, $rows)
        if (-not $name) {
            if ($this.Picker.Miss -eq "none") { return [ActionResult]::Nok("AddPack : no instance") }
            return [ActionResult]::Ok("AddPack : cancelled")
        }

        $view = $this.GetView("AddPack")
        try {
            $packs = $this.Service.GetPacks($name)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("AddPack : $name - $($_.Exception.Message)")
        }

        if (@($packs.Candidate).Count -eq 0) {
            $view.ShowAlreadyComplete($name)
            return [ActionResult]::Ok("AddPack : cancelled")
        }
        if (@($packs.Installed).Count -gt 0) {
            $view.ShowAlreadyIn($name, @($packs.Installed))
        }

        $pack = $view.AskPack($name, @($packs.Candidate))
        if (-not $pack) {
            $view.ShowCancelled("modified")
            return [ActionResult]::Ok("AddPack : cancelled")
        }

        $dto = [AddPackDto]::new()
        $dto.InstanceName = $name
        $dto.PackName = "$($pack.Name)"

        try {
            $response = $this.Service.AddPack($dto)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("AddPack : $($dto.InstanceName) - $($_.Exception.Message)")
        }
        $view.Show($response)
        return [ActionResult]::Ok("AddPack : $($dto.InstanceName)")
    }
}
