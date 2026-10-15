# ==============================================================================
# SELECTINSTANCE — LE PRESENTER
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\..\BasePresenter.psm1

# La question partagée : « quelle instance ? » — un presenter pour cette vue
# comme pour les autres, tenu par les gestes qui en ont besoin. C'est ICI que
# le tri, le vide et l'abandon se décident ; la vue ne fait que demander et
# rendre ce qu'on a piqué. Pick rend le nom, ou rien — et Miss dit pourquoi
# la course s'arrête :
#
#   ""            le nom est là
#   "cancelled"   l'utilisateur est sorti (Échap) — une annulation
#   "none"        rien à choisir — le refus, qui sort en faute
class SelectInstancePresenter : BasePresenter {
    [string]$Miss = ""

    SelectInstancePresenter([string]$viewsRoot, [string]$viewType) : base($viewsRoot, $viewType, "Instance") {
    }

    [string] Pick([string]$target, [object[]]$rows) {
        $this.Miss = ""
        if ($target) { return $target }

        $all = @($rows | Where-Object { -not $_.IsArchive })
        if ($all.Count -eq 0) {
            $this.GetView("SelectInstance").ShowNoInstances()
            $this.Miss = "none"
            return ""
        }

        $picked = $this.GetView("SelectInstance").AskOffered($all)
        if (-not $picked) {
            $this.Miss = "cancelled"
            return ""
        }
        return "$picked"
    }
}
