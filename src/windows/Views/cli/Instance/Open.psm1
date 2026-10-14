# ==============================================================================
# OPEN — LA VUE DU CLI
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewCli.psm1

class CliOpenView : BaseViewCli {
    # Pas de question : le nom arrive déjà choisi, et la ligne du geste part
    # avant l'attente.
    [void] Ask([string]$name) {
        Write-Host ""
        Write-Host "==> Opening a shell in '$name'..." -ForegroundColor $this.Colour("info")
    }

    # Le rapport : rien — la fenêtre qui part EST le rapport. La réponse dit
    # si le profil Terminal l'a portée ou si c'est la console nue :
    # l'utilisateur le voit à sa fenêtre, il n'y a rien à écrire ici.
    [void] Show([string]$name, [object]$response) {
    }
}
