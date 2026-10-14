# ==============================================================================
# ERROR — LA VUE D'ERREUR DU CLI
# ==============================================================================
# Le refus de n'importe quel geste, peint ici une seule fois : le contrôleur
# n'envoie que la phrase du service, et la même vue sert tous les gestes. Le
# code de sortie, lui, n'est pas ici : l'entrée du cli le lit de l'ActionResult
# du geste.
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewCli.psm1

class CliErrorView : BaseViewCli {
    [void] Show([string]$failure) {
        Write-Host ""
        Write-Host "[FAIL] $failure" -ForegroundColor $this.Colour("error")
        Write-Host ""
    }
}
