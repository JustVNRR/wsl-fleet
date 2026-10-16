# ==============================================================================
# LIST — LE PRESENTER
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\ActionResult.psm1
using module ..\BasePresenter.psm1
using module ..\..\Services\InstanceService.psm1
using module ..\..\Dtos\InstanceDto.psm1

# Le tableau : les lectures ici — les instances, les dossiers laissés
# derrière, qui tourne (une fois pour tout le tableau) — la vue montre. Rien
# du tout est un refus, dit par le code de sortie ; l'ActionResult est la
# seule sortie.
class ListPresenter : BasePresenter {
    hidden [InstanceService]$Service

    ListPresenter([InstanceService]$service, [string]$viewsRoot, [string]$viewType) : base($viewsRoot, $viewType, "Instance") {
        $this.Service = $service
    }

    [ActionResult] Run() {
        $view = $this.GetView("List")
        try {
            $rows = @($this.Service.GetAll())
            $orphans = @($this.Service.GetOrphans())
            $running = @($this.Service.GetRunningNames())
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("List : $($_.Exception.Message)")
        }
        # Le Dto du tableau, assemblé ici : une seule chose à peindre pour la
        # vue, et rien à lire au service d'aucun côté.
        $index = [ListResponseDto]::new()
        $index.Rows = @($rows)
        $index.Orphans = @($orphans)
        $index.Running = @($running)
        $view.Show($index)
        if (($rows.Count + $orphans.Count) -eq 0) { return [ActionResult]::Nok("List : none") }
        return [ActionResult]::Ok("List : $($rows.Count + $orphans.Count) row(s)")
    }
}
