# ==============================================================================
# DUPLICATE — LE PRESENTER
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\ActionResult.psm1
using module ..\BasePresenter.psm1
using module .\shared\SelectInstancePresenter.psm1
using module ..\..\Services\InstanceService.psm1
using module ..\..\Dtos\InstanceDto.psm1

# La copie : le nom se demande jusqu'à ce qu'il en soit un — la boucle et la
# règle sont ici, la vue ne fait que poser la question et dire l'indice de
# refus ; le vide annule. Puis l'avis du disque immobile, qui couvre les deux
# cas sans lire qui tourne, et l'appel.
class DuplicatePresenter : BasePresenter {
    hidden [InstanceService]$Service

    [SelectInstancePresenter]$Picker

    DuplicatePresenter([InstanceService]$service, [string]$viewsRoot, [string]$viewType) : base($viewsRoot, $viewType, "Instance") {
        $this.Service = $service
        $this.Picker = [SelectInstancePresenter]::new($viewsRoot, $viewType)
    }

    [ActionResult] Run([string]$target) {
        try {
            $rows = @($this.Service.GetAll())
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Duplicate : $($_.Exception.Message)")
        }

        $source = $this.Picker.Pick($target, $rows)
        if (-not $source) {
            if ($this.Picker.Miss -eq "none") { return [ActionResult]::Nok("Duplicate : no instance") }
            return [ActionResult]::Ok("Duplicate : cancelled")
        }

        # Le nom de la copie, demandé jusqu'à ce qu'il en soit un — la forme
        # vérifiée, l'indice de refus montré, le vide qui annule.
        $view = $this.GetView("Duplicate")
        $copy = ""
        while ($true) {
            $answer = $view.AskCopyName()
            if (-not $answer) {
                $view.ShowCancelled("created")
                return [ActionResult]::Ok("Duplicate : cancelled")
            }
            if ($answer -match '^[A-Za-z0-9][A-Za-z0-9_.-]*$') { $copy = $answer; break }
            $view.ShowNameHint()
        }

        $view.ShowDiskWarning($source)
        if (-not $view.Confirm("Continue?", $false)) {
            $view.ShowCancelled("created")
            return [ActionResult]::Ok("Duplicate : cancelled")
        }
        $view.ShowDuplicating($source, $copy)

        $dto = [DuplicateDto]::new()
        $dto.SourceName = $source
        $dto.CopyName = $copy

        try {
            $response = $this.Service.Duplicate($dto)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Duplicate : $source - $($_.Exception.Message)")
        }
        $view.Show($response)
        return [ActionResult]::Ok("Duplicate : $copy")
    }
}
