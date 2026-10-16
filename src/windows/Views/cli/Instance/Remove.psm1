# ==============================================================================
# REMOVE — LA VUE DU CLI
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewCli.psm1

class CliRemoveView : BaseViewCli {
    # La vue ne décide plus : l'écran de la porte, la lecture du nom, les
    # lignes — et c'est le presenter qui compare et qui tranche.

    # L'écran de la destruction : la bannière, la phrase, les règles — la
    # lecture suit, posée par le presenter.
    [void] ShowDestructionGate([string]$name, [string]$lead) {
        [Console]::Beep(1000, 400)
        Write-Host ""
        $this.ShowDangerBanner("DANGER: TOTAL DATA LOSS IMMINENT")
        Write-Host ""
        Write-Host "  $lead" -ForegroundColor $this.Colour("error")
        Write-Host ""
        Write-Host "  Proceeding will PERMANENTLY DESTROY this distribution:" -ForegroundColor $this.Colour("warning")
        Write-Host "    - Executing: wsl --unregister $name" -ForegroundColor $this.Colour("muted")
        Write-Host "    - IRREVERSIBLE DELETION of the virtual disk (VHDX)" -ForegroundColor $this.Colour("muted")
        Write-Host "    - TOTAL LOSS of projects, SSH keys, and all files in /home" -ForegroundColor $this.Colour("muted")
        Write-Host ""
        Write-Host "  THIS OPERATION CANNOT BE UNDONE." -ForegroundColor $this.Colour("error")
        Write-Host ""
        Write-Host " ----------------------------------------------------------------------" -ForegroundColor $this.Colour("muted")
        Write-Host " Press ENTER to abort immediately." -ForegroundColor $this.Colour("hint")
        Write-Host " To confirm DESTRUCTION, type the name of the distribution:" -ForegroundColor $this.Colour("hint")
    }

    # Le nom retapé, lu — Read-Host est demandé nu : ce qu'il écrit lui-même
    # n'atteint jamais un pipe.
    [string] AskTypedName() {
        return [string](Read-Host " Confirm")
    }

    # La règle de clôture de la porte, les deux chemins la portent.
    [void] ShowGateClose() {
        Write-Host " ----------------------------------------------------------------------" -ForegroundColor $this.Colour("muted")
        Write-Host ""
    }

    # La porte passée : le souffle avant la question suivante.
    [void] ShowGateOpened() {
        Write-Host ""
    }

    [void] ShowGateRefused() {
        Write-Host "[ABORT] Operation cancelled. No data was modified." -ForegroundColor $this.Colour("warning")
    }

    # L'écrasement de l'archive, dit — le presenter l'a lu de l'index.
    [void] ShowReplacingArchive([string]$name) {
        Write-Host "  '$name' exists: replacing its archive." -ForegroundColor $this.Colour("warning")
    }

    [void] ShowRemovingSteps() {
        Write-Host "==> Stopping the distro processes..." -ForegroundColor $this.Colour("info")
        Write-Host "==> Unregistering the distro..." -ForegroundColor $this.Colour("info")
    }

    # Le rapport : la bannière, et la phrase de Windows Terminal. Les détails
    # de l'ancien écran — ce que le dossier est devenu, les comptes des
    # fantômes et des fragments, la copie — n'ont plus de source : le service
    # ne rend rien, la vue ne reçoit rien, et l'échec passe par la vue
    # d'erreur.
    [void] Show() {
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor $this.Colour("success")
        Write-Host "                WSL Stack Instance Removed!                 " -ForegroundColor $this.Colour("success")
        Write-Host "============================================================" -ForegroundColor $this.Colour("success")
        Write-Host ""
        Write-Host ""
        Write-Host " Restart Windows Terminal to refresh the profile list."
        Write-Host ""
    }
}
