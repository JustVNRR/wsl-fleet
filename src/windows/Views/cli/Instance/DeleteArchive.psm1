# ==============================================================================
# DELETEARCHIVE — LA VUE DU CLI
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewCli.psm1

class CliDeleteArchiveView : BaseViewCli {
    # La question, s'il en faut une : le nom de l'archive arrive par la ligne
    # de commande — ce geste n'est offert dans aucun menu, et le nom tapé EST
    # la confirmation. Sans nom, rien à faire, et la liste dit où les lire :
    # la vue rend vide, le contrôleur s'arrête là.
    [string] Ask([string]$target) {
        if ([string]::IsNullOrWhiteSpace($target)) {
            Write-Host ""
            Write-Host "[ABORT] No archive name was given." -ForegroundColor $this.Colour("error")
            Write-Host "        The archives are listed by  .\wsl.ps1 list" -ForegroundColor $this.Colour("hint")
            Write-Host "        Then:  .\wsl.ps1 delete_archive <name>" -ForegroundColor $this.Colour("hint")
            return ""
        }

        Write-Host ""
        Write-Host "==> Deleting the archive '$target'..." -ForegroundColor $this.Colour("info")
        return $target
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
