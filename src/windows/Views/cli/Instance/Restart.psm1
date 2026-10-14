# ==============================================================================
# RESTART — LA VUE DU CLI
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewCli.psm1

class CliRestartView : BaseViewCli {
    # Les questions du geste : le nom arrive déjà choisi (SelectInstance a
    # demandé) — l'avis du travail non sauvé, puis le oui. La ligne du geste
    # part à la fin, avant l'attente.
    [void] Ask([string]$name) {
        Write-Host ""
        Write-Host "  '$name' will be stopped, then started again." -ForegroundColor $this.Colour("warning")
        Write-Host "  Whatever is open in there and not saved is lost; what is already" -ForegroundColor $this.Colour("warning")
        Write-Host "  written on the disk stays exactly as it is." -ForegroundColor $this.Colour("warning")
        if (-not $this.Confirm("Restart it?", $false)) { $this.StopCancelled("modified") }

        Write-Host ""
        Write-Host "==> Restarting '$name'..." -ForegroundColor $this.Colour("info")
    }

    # Le rapport : la bannière. Le chemin du dossier et la taille du disque ne
    # sont plus montrés : rien de tout ça ne traverse, et la vue ne lit pas.
    [void] Show([string]$name, [object]$response) {
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor $this.Colour("success")
        Write-Host "       '$name' is running again" -ForegroundColor $this.Colour("success")
        Write-Host "============================================================" -ForegroundColor $this.Colour("success")
        Write-Host ""
        Write-Host ""
    }
}
