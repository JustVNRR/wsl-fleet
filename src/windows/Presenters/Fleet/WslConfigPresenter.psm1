using module ..\ActionResult.psm1
using module ..\BasePresenter.psm1
using module ..\..\Services\FleetService.psm1

class WslConfigPresenter : BasePresenter {
    hidden [FleetService]$Service

    WslConfigPresenter([FleetService]$service, [string]$viewsRoot, [string]$viewType) : base($viewsRoot, $viewType, "Fleet") {
        $this.Service = $service
    }

    [ActionResult] Run() {
        $view = $this.GetView("WslConfig")
        $view.ShowLead()
        try {
            $report = $this.Service.WslConfig()
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("WslConfig : $($_.Exception.Message)")
        }
        $view.Show($report)
        return [ActionResult]::Ok("WslConfig : $($report.Path)")
    }
}
