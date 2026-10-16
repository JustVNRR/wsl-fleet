using module ..\ActionResult.psm1
using module ..\BasePresenter.psm1
using module .\shared\SelectInstancePresenter.psm1
using module ..\..\Services\InstanceService.psm1

class OpenPresenter : BasePresenter {

    hidden [InstanceService]$Service
    [SelectInstancePresenter]$Picker

    OpenPresenter([InstanceService]$service, [string]$viewsRoot, [string]$viewType) : base($viewsRoot, $viewType, "Instance") {
        $this.Service = $service
        $this.Picker = [SelectInstancePresenter]::new($viewsRoot, $viewType)
    }

    [ActionResult] Run([string]$target) {
        try {
            $rows = @($this.Service.GetAll())
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Open : $($_.Exception.Message)")
        }

        $name = $this.Picker.Pick($target, $rows)
        if (-not $name) {
            if ($this.Picker.Miss -eq "none") { return [ActionResult]::Nok("Open : no instance") }
            return [ActionResult]::Ok("Open : cancelled")
        }

        $view = $this.GetView("Open")
        $view.ShowOpening($name)
        try {
            $response = $this.Service.Open($name)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Open : $name - $($_.Exception.Message)")
        }
        $view.Show($response)
        return [ActionResult]::Ok("Open : $name")
    }
}
