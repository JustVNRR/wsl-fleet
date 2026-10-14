# ==============================================================================
# GETAPPEARANCE — LA VUE DU CLI
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewCli.psm1

# Le constat du look : ce que l'instance porte, tel que le service l'a lu —
# la police, les couleurs, la tuile, et l'avertissement du fragment quand il
# manque. Rien à demander : le contrôleur lit, la vue peint.
class CliGetAppearanceView : BaseViewCli {
    [void] Show([string]$name, [object]$response) {
        Write-Host ""
        Write-Host "Theme of '$name'" -ForegroundColor $this.Colour("info")
        Write-Host ""
        Write-Host "  Font    : $($response.Font)" -ForegroundColor $this.Colour("muted")
        Write-Host "  Colours : $($response.ColourScheme)" -ForegroundColor $this.Colour("muted")
        if ($response.Icon -and $response.Icon.Text) {
            Write-Host "  Icon    : $($response.Icon.Text)   $($response.Icon.Top) -> $($response.Icon.Bottom)   (text $($response.Icon.TextColor))" -ForegroundColor $this.Colour("muted")
        } else {
            Write-Host "  Icon    : drawn from the name (By Default)" -ForegroundColor $this.Colour("muted")
        }

        if (-not $response.HasFragment) {
            Write-Host ""
            Write-Host "[WARNING] This instance has no Terminal profile of ours - the look would not show." -ForegroundColor $this.Colour("warning")
            Write-Host "          Build it again, or set it by hand in Ctrl+," -ForegroundColor $this.Colour("muted")
        }
        Write-Host ""
    }
}
