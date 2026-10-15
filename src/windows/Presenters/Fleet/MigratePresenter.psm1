# ==============================================================================
# MIGRATE — LE PRESENTER
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\ActionResult.psm1
using module ..\BasePresenter.psm1
using module ..\..\Service\FleetService.psm1
using module ..\..\Tools\Helpers.psm1

# Le déménagement : une seule question — le dossier d'arrivée, posée avec la
# racine en main — et les deux refus qui ne coûtent rien, lus ICI : le dossier
# qui EST la racine, et la cible que Test-FleetTarget refuse. Une cible DONNÉE
# (le lancement depuis la fenêtre) passe les deux — comme avant. Puis le
# voyage entier, au service. L'ActionResult est la seule sortie.
class MigratePresenter : BasePresenter {
    hidden [FleetService]$Service

    MigratePresenter([FleetService]$service, [string]$viewsRoot, [string]$viewType) : base($viewsRoot, $viewType, "Fleet") {
        $this.Service = $service
    }

    [ActionResult] Run([string]$target) {
        $view = $this.GetView("Migrate")
        try {
            $root = $this.Service.GetRoot()
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Migrate : $($_.Exception.Message)")
        }

        if (-not $target) {
            $answer = $view.AskTarget($root)
            if (-not $answer) {
                $view.ShowCancelled("moved")
                return [ActionResult]::Ok("Migrate : cancelled")
            }
            $answer = "$answer".Trim().Trim('"').TrimEnd('\')
            if ($answer -eq "$root".TrimEnd('\')) {
                $view.ShowSameFolder()
                return [ActionResult]::Ok("Migrate : cancelled")
            }
            $problem = Test-FleetTarget $answer
            if ($problem) {
                $view.ShowTargetProblem($problem)
                return [ActionResult]::Ok("Migrate : cancelled")
            }
            $target = $answer
        }

        $view.ShowLead()
        try {
            $response = $this.Service.Migrate($target)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Migrate : $($_.Exception.Message)")
        }

        $view.Show($response.Target, $response.Moved)
        return [ActionResult]::Ok("Migrate : $($response.Target)")
    }
}
