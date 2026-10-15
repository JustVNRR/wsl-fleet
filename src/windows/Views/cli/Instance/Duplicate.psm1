# ==============================================================================
# DUPLICATE — LA VUE DU CLI
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewCli.psm1

class CliDuplicateView : BaseViewCli {
    # La vue ne décide plus : la boucle du nom, la règle, l'avis et le oui
    # sont au presenter — ici, la question, l'indice de refus et les lignes.

    # Le nom de la copie, lu — la question et rien d'autre ; ce qu'un vide ou
    # une forme refusée veulent dire reste au presenter.
    [string] AskCopyName() {
        return [string](Read-Host "Name of the copy").Trim()
    }

    [void] ShowNameHint() {
        Write-Host "  Letters, digits, '.', '_' and '-' only." -ForegroundColor $this.Colour("hint")
    }

    # L'avis du disque immobile — il couvre les deux cas sans lire qui
    # tourne ; « Continue ? » se pose à la vue, le presenter la pose.
    [void] ShowDiskWarning([string]$source) {
        Write-Host ""
        Write-Host "  If '$source' is running, this will stop it: the copy reads a still disk." -ForegroundColor $this.Colour("warning")
        Write-Host "  Save what you have open in there - stopping it loses anything unsaved." -ForegroundColor $this.Colour("warning")
    }

    [void] ShowDuplicating([string]$source, [string]$copy) {
        Write-Host ""
        Write-Host "==> Duplicating '$source' into '$copy'" -ForegroundColor $this.Colour("info")
        Write-Host "==> 1. Reading the source (the source itself is not modified)..." -ForegroundColor $this.Colour("info")
        Write-Host "==> 2. Registering '$copy' from it..." -ForegroundColor $this.Colour("info")
    }

    # Le rapport : la bannière — la copie (-Response) et l'originale (-Target)
    # — et les deux phrases de Terminal. La place, le look reposé, la réponse
    # de Docker Desktop et l'état rendu n'ont plus de source.
    [void] Show([string]$source, [object]$response) {
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor $this.Colour("success")
        Write-Host "       '$($response)' is a copy of '$source'" -ForegroundColor $this.Colour("success")
        Write-Host "============================================================" -ForegroundColor $this.Colour("success")
        Write-Host ""
        Write-Host "  Windows Terminal: the copy gets a profile of its own, with the icon," -ForegroundColor $this.Colour("muted")
        Write-Host "  the font and the colours of the source. Restart Terminal to see it." -ForegroundColor $this.Colour("muted")
        Write-Host ""
    }
}
