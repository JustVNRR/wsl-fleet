# ==============================================================================
# RESTART — LE PRESENTER
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\ActionResult.psm1
using module ..\BasePresenter.psm1
using module .\shared\SelectInstancePresenter.psm1
using module ..\..\Services\InstanceService.psm1

# L'arrêt et le départ : l'avis d'abord, le oui relu ici, la ligne du geste —
# la vue affiche et demande, elle ne décide plus. L'ActionResult est la seule
# sortie.
class RestartPresenter : BasePresenter {
    hidden [InstanceService]$Service

    [SelectInstancePresenter]$Picker

    RestartPresenter([InstanceService]$service, [string]$viewsRoot, [string]$viewType) : base($viewsRoot, $viewType, "Instance") {
        $this.Service = $service
        $this.Picker = [SelectInstancePresenter]::new($viewsRoot, $viewType)
    }

    [ActionResult] Run([string]$target) {
        try {
            $rows = @($this.Service.GetAll())
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Restart : $($_.Exception.Message)")
        }

        $name = $this.Picker.Pick($target, $rows)
        if (-not $name) {
            if ($this.Picker.Miss -eq "none") { return [ActionResult]::Nok("Restart : no instance") }
            return [ActionResult]::Ok("Restart : cancelled")
        }

        $view = $this.GetView("Restart")
        $view.ShowStoppingWarning($name)
        if (-not $view.AskRestart()) {
            $view.ShowCancelled("modified")
            return [ActionResult]::Ok("Restart : cancelled")
        }
        $view.ShowRestarting($name)

        try {
            $response = $this.Service.Restart($name)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Restart : $name - $($_.Exception.Message)")
        }
        $view.Show($response)
        return [ActionResult]::Ok("Restart : $name")
    }
}
