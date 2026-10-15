# ==============================================================================
# WSLCONFIG — LA VUE DU CLI
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewCli.psm1

# Le fichier des réglages Windows : l'annonce avant l'ouverture, puis le
# rapport — né de son gabarit quand il manquait, ou son chemin.
class CliWslConfigView : BaseViewCli {
    [void] ShowLead() {
        Write-Host ""
        Write-Host "==> Opening .wslconfig" -ForegroundColor $this.Colour("info")
    }

    [void] Show([string]$path, [bool]$created) {
        if ($created) {
            Write-Host "  * .wslconfig : " -NoNewline
            Write-Host "file created" -ForegroundColor $this.Colour("success")
        } else {
            Write-Host "  * .wslconfig : " -NoNewline
            Write-Host "$path" -ForegroundColor $this.Colour("info")
        }
    }
}
