# ==============================================================================
# DELETEARCHIVE — LA VUE DU CLI
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewCli.psm1

class CliDeleteArchiveView : BaseViewCli {
    # La vue ne décide plus : le nom vient de la ligne de commande, le
    # presenter a constaté son absence ou sa présence — ici, les lignes.

    # Sans nom, rien à faire : le refus, peint ici — le presenter sort en
    # faute.
    [void] ShowNoName() {
        Write-Host ""
        Write-Host "[ABORT] No archive name was given." -ForegroundColor $this.Colour("error")
        Write-Host "        The archives are listed by  .\wsl.ps1 list" -ForegroundColor $this.Colour("hint")
        Write-Host "        Then:  .\wsl.ps1 delete_archive <name>" -ForegroundColor $this.Colour("hint")
    }

    [void] ShowDeleting([string]$name) {
        Write-Host ""
        Write-Host "==> Deleting the archive '$name'..." -ForegroundColor $this.Colour("info")
    }

    # Le rapport : la bannière et l'irréversible. Le poids rendu et le dossier
    # n'ont plus de source — le service ne rend rien.
    [void] Show([string]$name, [object]$response) {
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor $this.Colour("success")
        Write-Host "       Archive '$name' deleted" -ForegroundColor $this.Colour("success")
        Write-Host "============================================================" -ForegroundColor $this.Colour("success")
        Write-Host ""
        Write-Host "  * Gone for good - no trash, no copy kept." -ForegroundColor $this.Colour("muted")
        Write-Host ""
    }
}
