# ==============================================================================
# WSLCONFIG — LE PRESENTER
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\ActionResult.psm1
using module ..\BasePresenter.psm1
using module ..\..\Services\FleetService.psm1

# Le fichier des réglages Windows : l'annonce, l'ouverture au service — né de
# son gabarit quand il manquait — puis le rapport. L'ActionResult est la
# seule sortie.
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
