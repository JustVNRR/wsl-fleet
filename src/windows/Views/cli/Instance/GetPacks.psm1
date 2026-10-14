# ==============================================================================
# GETPACKS — LA VUE DU CLI
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewCli.psm1

class CliGetPacksView : BaseViewCli {
    # Le rapport : les trois listes du service — portés, offrables, retirables.
    # Ce geste ne fait que lire : pas de question, pas de Ask.
    [void] Show([string]$name, [object]$response) {
        Write-Host ""
        Write-Host "Packs of '$name':" -ForegroundColor $this.Colour("info")
        if ($response.Installed.Count -eq 0) {
            Write-Host "  * Carried          : none" -ForegroundColor $this.Colour("muted")
        } else {
            Write-Host "  * Carried          : $($response.Installed -join ', ')" -ForegroundColor $this.Colour("muted")
        }
        if ($response.Candidate.Count -gt 0) {
            $names = @($response.Candidate | ForEach-Object { $_.Name })
            Write-Host "  * Offered          : $($names -join ', ')" -ForegroundColor $this.Colour("muted")
        }
        if ($response.Removable.Count -gt 0) {
            Write-Host "  * Removable        : $($response.Removable -join ', ')" -ForegroundColor $this.Colour("muted")
        }
        Write-Host ""
    }
}
