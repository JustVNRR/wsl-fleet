using module ..\ActionResult.psm1
using module ..\BasePresenter.psm1
using module .\shared\SelectInstancePresenter.psm1
using module ..\..\Services\InstanceService.psm1
using module ..\..\Dtos\InstanceDto.psm1

class RemovePresenter : BasePresenter {
    hidden [InstanceService]$Service

    [SelectInstancePresenter]$Picker

    RemovePresenter([InstanceService]$service, [string]$viewsRoot, [string]$viewType) : base($viewsRoot, $viewType, "Instance") {
        $this.Service = $service
        $this.Picker = [SelectInstancePresenter]::new($viewsRoot, $viewType)
    }

    [ActionResult] Run([string]$target) {
        try {
            $rows = @($this.Service.GetAll())
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Remove : $($_.Exception.Message)")
        }

        $name = $this.Picker.Pick($target, $rows)
        if (-not $name) {
            if ($this.Picker.Miss -eq "none") { return [ActionResult]::Nok("Remove : no instance") }
            return [ActionResult]::Ok("Remove : cancelled")
        }

        $view = $this.GetView("Remove")
        $view.ShowDestructionGate($name, "The WSL distribution '$name' and ALL its data will be deleted:")
        $typed = $view.AskTypedName()
        $view.ShowGateClose()
        if ($typed -ne $name) {
            $view.ShowGateRefused()
            return [ActionResult]::Ok("Remove : cancelled")
        }
        $view.ShowGateOpened()

        $archiveFirst = $view.Confirm("Archive it before deleting?", $true)
        if ($archiveFirst) {
            if (@($rows | Where-Object { $_.IsArchive -and "$($_.Name)" -eq "$($name)_archive" }).Count -gt 0) {
                $view.ShowReplacingArchive($name)
            }
        }
        $view.ShowRemovingSteps()

        $dto = [RemoveDto]::new()
        $dto.InstanceName = $name
        $dto.ArchiveFirst = [bool]$archiveFirst

        try {
            $this.Service.Remove($dto)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Remove : $name - $($_.Exception.Message)")
        }
        $view.Show()
        return [ActionResult]::Ok("Remove : $name")
    }
}
