# ==============================================================================
# REMOVE — LE PRESENTER
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\ActionResult.psm1
using module ..\BasePresenter.psm1
using module .\shared\SelectInstancePresenter.psm1
using module ..\..\Services\InstanceService.psm1
using module ..\..\Dtos\InstanceDto.psm1

# La destruction : la porte qui demande le nom retapé vit ici — la
# comparaison est une décision, la vue ne porte que l'écran et la lecture. Le dernier moment
# pour une copie, la ligne de l'écrasement lue de l'index, les avis du geste
# qui part : tout se décide ici, et l'ActionResult est la seule sortie.
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

        # La porte de la destruction : l'écran, le nom retapé lu, et la
        # comparaison qui décide — le nom, la casse ignorée.
        $view = $this.GetView("Remove")
        $view.ShowDestructionGate($name, "The WSL distribution '$name' and ALL its data will be deleted:")
        $typed = $view.AskTypedName()
        $view.ShowGateClose()
        if ($typed -ne $name) {
            $view.ShowGateRefused()
            return [ActionResult]::Ok("Remove : cancelled")
        }
        $view.ShowGateOpened()

        # Le dernier moment pour une copie — et l'écrasement, dit, lu de
        # l'index reçu.
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
