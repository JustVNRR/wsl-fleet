# ==============================================================================
# DELETEARCHIVE — LE PRESENTER
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\ActionResult.psm1
using module ..\BasePresenter.psm1
using module ..\..\Service\InstanceService.psm1

# La corbeille d'une archive : le nom vient de la ligne de commande — ce
# geste n'est offert dans aucun menu, et le nom tapé EST la confirmation.
# Sans nom, rien à faire — le refus est un refus, il sort en faute comme les
# autres abandons.
class DeleteArchivePresenter : BasePresenter {
    hidden [InstanceService]$Service

    DeleteArchivePresenter([InstanceService]$service, [string]$viewsRoot, [string]$viewType) : base($viewsRoot, $viewType, "Instance") {
        $this.Service = $service
    }

    [ActionResult] Run([string]$target) {
        $view = $this.GetView("DeleteArchive")
        if ([string]::IsNullOrWhiteSpace($target)) {
            $view.ShowNoName()
            return [ActionResult]::Nok("DeleteArchive : no name")
        }

        $view.ShowDeleting($target)
        try {
            $this.Service.DeleteArchive($target)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("DeleteArchive : $target - $($_.Exception.Message)")
        }
        $view.Show($target, $null)
        return [ActionResult]::Ok("DeleteArchive : $target")
    }
}
