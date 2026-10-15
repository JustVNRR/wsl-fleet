# ==============================================================================
# ADDPACK — LA VUE DU CLI
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewCli.psm1

class CliAddPackView : BaseViewCli {
    # La vue ne décide plus : le catalogue lu au service, le vide constaté, le
    # Dto bâti et l'Échap lu sont au presenter — ici, les lignes et la
    # question.

    # Tout est déjà là : la réponse du catalogue, dite.
    [void] ShowAlreadyComplete([string]$name) {
        Write-Host ""
        Write-Host "[OK] '$name' already has every pack this repository offers." -ForegroundColor $this.Colour("success")
    }

    # Les portés, dits avant la liste — les flèches redessinent par-dessus.
    [void] ShowAlreadyIn([string]$name, [object[]]$installed) {
        Write-Host ""
        Write-Host ("       Already in '$name': {0}" -f ($installed -join ", ")) -ForegroundColor $this.Colour("muted")
    }

    # Le pack, choisi : le catalogue reçu, ses lignes. Rien quand on sort — le
    # presenter le lit comme un abandon.
    [object] AskPack([string]$name, [object[]]$candidates) {
        $Pack = $this.AskList("Packs available for '$name':", @($candidates), {
            param($Entry)
            "{0,-12} {1}" -f $Entry.Name, $Entry.Description
        }, "")
        if (-not $Pack) { return "" }
        return $Pack
    }

    # Le rapport : le déroulé du service, mot pour mot — un pack qui décline
    # n'est pas un échec, un pack à moitié installé se redit et se reprend, et
    # ce qui est entré se relit.
    [void] Show([object]$response) {
        if ($response.Outcome -eq "copy-failed") {
            Write-Host "[ABORT] Could not copy the pack's files into '$($response.InstanceName)' (exit code $($response.ExitCode))." -ForegroundColor $this.Colour("error")
            Write-Host "        The message above says what refused: the instance, or Windows." -ForegroundColor $this.Colour("hint")
            Write-Host ""
            return
        }

        # A half-installed pack is worse than none: the Makefile loads
        # whatever folder is there, so the menu would offer commands whose
        # tool was never installed. The folder went back out - and only it:
        # what the install already wrote stays, and running this again picks
        # up there.
        if ($response.Outcome -eq "failed") {
            Write-Host ""
            Write-Host "[FAIL] The installation did not complete (exit code $($response.ExitCode))." -ForegroundColor $this.Colour("error")
            Write-Host "       The pack's files were removed." -ForegroundColor $this.Colour("hint")
            Write-Host "       Whatever the install had already put in place is still there - run this again to finish." -ForegroundColor $this.Colour("hint")
            Write-Host ""
            return
        }

        Write-Host ""
        if ($response.Installed.Count -gt 0) {
            Write-Host "       Installed: $($response.Installed -join ', ')" -ForegroundColor $this.Colour("success")
        }
        if ($response.Skipped.Count -gt 0) {
            Write-Host "       Already there: $($response.Skipped -join ', ')" -ForegroundColor $this.Colour("muted")
        }
    }
}
