# ==============================================================================
# RESTART — LA VUE DU CLI
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewCli.psm1

class CliRestartView : BaseViewCli {
    # La vue ne décide plus : le oui se relit au presenter — ici, l'avis, la
    # porte et la ligne du geste.

    # L'avis du travail non sauvé, avant la question.
    [void] ShowStoppingWarning([string]$name) {
        Write-Host ""
        Write-Host "  '$name' will be stopped, then started again." -ForegroundColor $this.Colour("warning")
        Write-Host "  Save your work before proceeding." -ForegroundColor $this.Colour("warning")
    }

    # La porte : le blank et la question, ensemble. Ce que la réponse veut
    # dire reste au presenter.
    [bool] AskRestart() {
        Write-Host ""
        return $this.Confirm("Restart it?", $false)
    }

    # La ligne du geste qui part, avant l'attente.
    [void] ShowRestarting([string]$name) {
        Write-Host ""
        Write-Host "==> Restarting '$name'..." -ForegroundColor $this.Colour("info")
    }

    # Le rapport : la bannière. Le chemin du dossier et la taille du disque ne
    # sont plus montrés : rien de tout ça ne traverse, et la vue ne lit pas.
    [void] Show([object]$response) {
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor $this.Colour("success")
        Write-Host "       '$($response.InstanceName)' is running again" -ForegroundColor $this.Colour("success")
        Write-Host "============================================================" -ForegroundColor $this.Colour("success")
        Write-Host ""
        Write-Host ""
    }
}
