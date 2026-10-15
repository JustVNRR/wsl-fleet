# ==============================================================================
# COMPACT — LE PRESENTER
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\ActionResult.psm1
using module ..\BasePresenter.psm1
using module .\shared\SelectInstancePresenter.psm1
using module ..\..\Service\InstanceService.psm1
using module ..\..\Dto\InstanceDto.psm1

# Le compactage : la copie de sûreté d'abord — oui par défaut, compacter
# réécrit les métadonnées du disque —, la ligne de l'écrasement lue de
# l'index, les avis du geste, et l'appel. Le service rend si la copie fut
# prise et si l'instance est repartie : la vue le dit, le presenter décide.
class CompactPresenter : BasePresenter {
    hidden [InstanceService]$Service

    [SelectInstancePresenter]$Picker

    CompactPresenter([InstanceService]$service, [string]$viewsRoot, [string]$viewType) : base($viewsRoot, $viewType, "Instance") {
        $this.Service = $service
        $this.Picker = [SelectInstancePresenter]::new($viewsRoot, $viewType)
    }

    [ActionResult] Run([string]$target) {
        try {
            $rows = @($this.Service.GetAll())
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Compact : $($_.Exception.Message)")
        }

        $name = $this.Picker.Pick($target, $rows)
        if (-not $name) {
            if ($this.Picker.Miss -eq "none") { return [ActionResult]::Nok("Compact : no instance") }
            return [ActionResult]::Ok("Compact : cancelled")
        }

        $view = $this.GetView("Compact")
        $view.ShowBeforeQuestions()
        $archiveFirst = $view.Confirm("Archive it first?", $false)
        if (-not $archiveFirst) {
            $view.ShowNoArchive()
        } elseif (@($rows | Where-Object { $_.IsArchive -and "$($_.Name)" -eq "$($name)_archive" }).Count -gt 0) {
            $view.ShowReplacingArchive($name)
        }
        $view.ShowCompacting($name, $archiveFirst)

        $dto = [CompactDto]::new()
        $dto.InstanceName = $name
        $dto.ArchiveFirst = [bool]$archiveFirst

        try {
            $response = $this.Service.Compact($dto)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Compact : $name - $($_.Exception.Message)")
        }
        $view.Show($name, $response)
        return [ActionResult]::Ok("Compact : $name")
    }
}
