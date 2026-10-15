# ==============================================================================
# LE CONTRÔLEUR DE LA FLOTTE
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce type qu'il a tiré
# lui-même.
using module ..\Presenters\ActionResult.psm1
using module .\BaseController.psm1
using module ..\Service\FleetService.psm1
using module ..\Service\InstanceService.psm1
using module ..\Dto\InstanceDto.psm1

# La racine — sa lecture (GetRoot) et son écriture (SetRoot : l'initialisation
# la pose, le migrate la reprend) — et le déménagement, Migrate. Ses vues sont
# sous Views\<ViewType>\Fleet\ ; les deux portes de la racine n'en ont pas :
# elles sont appelées, pas demandées.
#
# Le déménagement : le dossier d'arrivée demandé par la vue (une cible
# DONNÉE — le lancement depuis la fenêtre — passe la question), la racine en
# main ; puis le voyage ENTIER, au service (FleetService.Migrate : la flotte
# de chez nous archivée et désinscrite UNE PAR UNE — l'espace se libère au
# fur et à mesure, le disque ne double jamais —, puis SetRoot, le dossier des
# archives qui voyage, la racine réécrite). Un échec arrête là — ce qui est
# déjà archivé et désinscrit l'est, et la course suivante reprend avec le
# reste. La boucle est muette : c'est le rapport qui nomme. Le registre n'est
# jamais touché autrement que par ces désinscriptions.
class FleetController : BaseController {
    hidden [FleetService]$Fleet

    FleetController([FleetService]$fleet, [string]$viewsRoot, [string]$viewType) : base($viewsRoot, $viewType, "Fleet") {
        $this.Fleet = $fleet
    }

    # La racine que la flotte habite — lue au service, rien à peindre.
    [ActionResult] GetRoot() {
        try {
            $root = $this.Fleet.GetRoot()
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("GetRoot : $($_.Exception.Message)")
        }
        return [ActionResult]::Ok("GetRoot : $root")
    }

    # La racine écrite — le dossier des archives voyage d'abord, la mémoire
    # suit ; un voyage raté laisse la racine où elle était.
    [ActionResult] SetRoot([string]$target) {
        try {
            $root = $this.Fleet.SetRoot($target)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("SetRoot : $target - $($_.Exception.Message)")
        }
        return [ActionResult]::Ok("SetRoot : $root")
    }

    # Le fichier des réglages Windows : l'annonce, l'ouverture au service,
    # puis le rapport — né de son gabarit quand il manquait, ou son chemin.
    [ActionResult] WslConfig() {
        $view = $this.GetView("WslConfig")
        $view.ShowLead()
        try {
            $report = $this.Fleet.WslConfig()
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("WslConfig : $($_.Exception.Message)")
        }
        $view.Show($report.Path, $report.Created)
        return [ActionResult]::Ok("WslConfig : $($report.Path)")
    }

    # Le déménagement : la vue demande où (une cible DONNÉE — le lancement
    # depuis la fenêtre — passe la question), puis peint le rapport qui
    # nomme. Rien à bouger (la vue le sait et l'a dit) : une fin, pas un
    # refus.
    [ActionResult] Migrate([string]$target) {
        $view = $this.GetView("Migrate")
        try {
            $root = $this.Fleet.GetRoot()
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Migrate : $($_.Exception.Message)")
        }

        if (-not $target) { $target = $view.Ask($root) }
        if (-not $target) { return [ActionResult]::Ok("Migrate : cancelled") }

        $view.ShowLead()
        try {
            $response = $this.Fleet.Migrate($target)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Migrate : $($_.Exception.Message)")
        }

        $view.Show($response.Target, $response.Moved)
        return [ActionResult]::Ok("Migrate : $($response.Target)")
    }
}
