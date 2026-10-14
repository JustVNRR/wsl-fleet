# ==============================================================================
# ADDPACK — LA VUE DU CLI
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewCli.psm1
using module ..\..\..\Dto\InstanceDto.psm1

class CliAddPackView : BaseViewCli {
    # La question du geste : le pack — ce que le catalogue offre à cette
    # famille et que l'instance n'a pas encore. Les listes viennent du
    # contrôleur (il a lu les packs au service) ; ce qui est déjà là se dit,
    # et une liste vide est déjà une réponse.
    [object] Ask([object]$packs, [string]$name) {
        $Installed = @($packs.Installed)
        $Candidates = @($packs.Candidate)

        if ($Candidates.Count -eq 0) {
            Write-Host ""
            Write-Host "[OK] '$name' already has every pack this repository offers." -ForegroundColor $this.Colour("success")
            return $null
        }

        # Said before the list, not after it: with the arrows the rows are
        # drawn in place, and anything under them gets painted over.
        if ($Installed.Count -gt 0) {
            Write-Host ""
            Write-Host ("       Already in '$name': {0}" -f ($Installed -join ", ")) -ForegroundColor $this.Colour("muted")
        }

        $Pack = $this.AskList("Packs available for '$name':", $Candidates, {
            param($Entry)
            "{0,-12} {1}" -f $Entry.Name, $Entry.Description
        }, "")
        if (-not $Pack) { $this.StopCancelled("modified") }

        $dto = [AddPackDto]::new()
        $dto.InstanceName = $name
        $dto.PackName = $Pack.Name
        return $dto
    }

    # Le rapport : le déroulé du service, mot pour mot — un pack qui décline
    # n'est pas un échec, un pack à moitié installé se redit et se reprend, et
    # ce qui est entré se relit.
    [void] Show([string]$name, [object]$response) {
        if ($response.Outcome -eq "declined") {
            Write-Host "       The pack's files were removed: it is not installed in '$name'." -ForegroundColor $this.Colour("hint")
            Write-Host ""
            return
        }

        if ($response.Outcome -eq "copy-failed") {
            Write-Host "[ABORT] Could not copy the pack's files into '$name' (exit code $($response.ExitCode))." -ForegroundColor $this.Colour("error")
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
