using module ..\ActionResult.psm1
using module ..\BasePresenter.psm1
using module .\shared\SelectInstancePresenter.psm1
using module ..\..\Services\InstanceService.psm1
using module ..\..\Dtos\InstanceDto.psm1

class RemovePackPresenter : BasePresenter {

    hidden [InstanceService]$Service
    [SelectInstancePresenter]$Picker

    RemovePackPresenter([InstanceService]$service, [string]$viewsRoot, [string]$viewType) : base($viewsRoot, $viewType, "Instance") {
        $this.Service = $service
        $this.Picker = [SelectInstancePresenter]::new($viewsRoot, $viewType)
    }

    [ActionResult] Run([string]$target) {
        try {
            $rows = @($this.Service.GetAll())
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("RemovePack : $($_.Exception.Message)")
        }

        $name = $this.Picker.Pick($target, $rows)
        if (-not $name) {
            if ($this.Picker.Miss -eq "none") { return [ActionResult]::Nok("RemovePack : no instance") }
            return [ActionResult]::Ok("RemovePack : cancelled")
        }

        $view = $this.GetView("RemovePack")
        try {
            $packs = $this.Service.GetPacks($name)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("RemovePack : $name - $($_.Exception.Message)")
        }

        if (@($packs.Installed).Count -eq 0) {
            $view.ShowNoPacks($name)
            return [ActionResult]::Ok("RemovePack : cancelled")
        }
        if (@($packs.Removable).Count -eq 0) {
            $view.ShowNoRemovable($name)
            return [ActionResult]::Ok("RemovePack : cancelled")
        }

        $packName = $view.AskPack($name, @($packs.Removable))
        if (-not $packName) {
            $view.ShowCancelled("modified")
            return [ActionResult]::Ok("RemovePack : cancelled")
        }
        if (-not $view.AskRemoval($packName)) {
            $view.ShowCancelled("modified")
            return [ActionResult]::Ok("RemovePack : cancelled")
        }
        $view.ShowRemoving($packName, $name)

        $dto = [RemovePackDto]::new()
        $dto.InstanceName = $name
        $dto.PackName = $packName

        try {
            $response = $this.Service.RemovePack($dto)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("RemovePack : $($dto.InstanceName) - $($_.Exception.Message)")
        }
        $view.Show($response)
        return [ActionResult]::Ok("RemovePack : $($dto.InstanceName)")
    }
}
