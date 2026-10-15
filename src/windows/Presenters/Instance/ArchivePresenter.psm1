# ==============================================================================
# ARCHIVE — LE PRESENTER
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\ActionResult.psm1
using module ..\BasePresenter.psm1
using module .\shared\SelectInstancePresenter.psm1
using module ..\..\Service\InstanceService.psm1
using module ..\..\Dto\InstanceDto.psm1

# L'archivage, mené d'un bout à l'autre : le presenter lit l'index, pose
# chaque question, lit chaque réponse, construit le Dto, appelle le service,
# ordonne le rapport — c'est la CAUSE qui décide, jamais la vue. La sortie :
# l'ActionResult, que l'entrée traduit en code.
#
# La première traversée : les autres gestes suivront la même forme, vue par
# vue, jusqu'à ce que les gros contrôleurs n'aient plus rien à porter.
class ArchivePresenter : BasePresenter {
    hidden [InstanceService]$Service

    # Le choix de l'instance : la question partagée, son propre presenter -
    # le banc pose ses fausses vues dans SES deux cartes (la sienne, celle du
    # choisisseur).
    [SelectInstancePresenter]$Picker

    ArchivePresenter([InstanceService]$service, [string]$viewsRoot, [string]$viewType) : base($viewsRoot, $viewType, "Instance") {
        $this.Service = $service
        $this.Picker = [SelectInstancePresenter]::new($viewsRoot, $viewType)
    }

    [ActionResult] Run([string]$target) {
        try {
            $rows = @($this.Service.GetAll())
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Archive : $($_.Exception.Message)")
        }

        $name = $this.Picker.Pick($target, $rows)
        if (-not $name) {
            if ($this.Picker.Miss -eq "none") { return [ActionResult]::Nok("Archive : no instance") }
            return [ActionResult]::Ok("Archive : cancelled")
        }

        # L'avis du disque immobile, sans condition parce que rien ne lit qui
        # tourne (la phrase couvre les deux cas) — puis le oui.
        $view = $this.GetView("Archive")
        $view.ShowStopWarning($name)
        if (-not $view.Confirm("Continue?", $false)) {
            $view.ShowCancelled("modified")
            return [ActionResult]::Ok("Archive : cancelled")
        }

        # Le nom de l'archive ne se demande pas : XX devient XX_archive. Le
        # format reste celui du dépôt, tar.gz. L'écrasement, lui, se DIT —
        # lu de l'index que la question a reçu.
        $archiveName = "$($name)_archive"
        if (@($rows | Where-Object { $_.IsArchive -and "$($_.Name)" -eq $archiveName }).Count -gt 0) {
            $view.ShowReplacing($archiveName)
        }
        $view.ShowBackingUp($name)

        $dto = [ArchiveDto]::new()
        $dto.InstanceName = $name
        $dto.Format = "tar.gz"
        $dto.Permit = $true

        try {
            $response = $this.Service.Archive($dto)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Archive : $name - $($_.Exception.Message)")
        }
        $view.Show($name, $response)
        return [ActionResult]::Ok("Archive : $name")
    }
}
