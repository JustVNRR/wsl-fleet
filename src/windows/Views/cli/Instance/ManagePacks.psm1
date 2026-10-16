# ==============================================================================
# MANAGEPACKS — LA VUE DU CLI
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewCli.psm1

class CliManagePacksView : BaseViewCli {
    # La vue ne décide plus : les listes lues au service, les lignes réunies,
    # le choix coché relu, ce qui entre et ce qui sort calculés et le Dto bâti
    # sont au presenter — ici, la checklist et les lignes.

    # Rien à choisir et rien à ajouter : la réponse, dite.
    [void] ShowNothingToChoose([string]$name) {
        Write-Host ""
        Write-Host "[OK] '$name' carries nothing to choose and this repository offers nothing to add." -ForegroundColor $this.Colour("success")
    }

    # La checklist : les lignes reçues, les cases déjà cochées reçues. $null
    # quand on sort — le presenter le lit comme un abandon.
    [object[]] AskPacks([string]$name, [object[]]$rows, [int[]]$checkedIndexes) {
        return $this.AskChecklist("Packs for '$name'", @($rows), {
            param($Row)
            "{0,-12} {1}" -f $Row.Name, $Row.Description
        }, @($checkedIndexes), "")
    }

    # Rien à faire : l'état demandé est déjà l'état porté — la réponse, dite.
    [void] ShowNothingToDo([string]$name) {
        Write-Host ""
        Write-Host "[OK] Nothing to do: '$name' already has exactly that." -ForegroundColor $this.Colour("success")
    }

    # Ticked and not installed goes in; carried and unticked comes out.
    [void] ShowPlan([string[]]$toAdd, [string[]]$toRemove) {
        Write-Host ""
        if (@($toAdd).Count -gt 0) {
            Write-Host "==> Installing: $($toAdd -join ', ')" -ForegroundColor $this.Colour("info")
        }
        if (@($toRemove).Count -gt 0) {
            Write-Host "==> Removing: $($toRemove -join ', ')" -ForegroundColor $this.Colour("info")
        }
    }

    # Le rapport : ce qui a bougé, lu des deux listages du service. La liste
    # entière des portés et le pas qui a échoué n'ont plus de source — la
    # réponse porte les entrés, les sortis et le nom du failli.
    [void] Show([object]$response) {
        # A failure names the pack; the packs already applied stay.
        if ($response.Outcome -eq "failed") {
            Write-Host ""
            Write-Host "[FAIL] '$($response.Failed -join ', ')' did not complete (exit code $($response.ExitCode))." -ForegroundColor $this.Colour("error")
            Write-Host "       The packs already applied stay - run this again to finish." -ForegroundColor $this.Colour("hint")
            Write-Host ""
            return
        }

        Write-Host ""
        if ($response.Installed.Count -gt 0) {
            Write-Host "==> '$($response.InstanceName)' now carries: $($response.Installed -join ', ')" -ForegroundColor $this.Colour("success")
            Write-Host "    Open a shell in it to use them:  .\wsl-fleet.ps1 shell" -ForegroundColor $this.Colour("muted")
        }
        if ($response.Removed.Count -gt 0) {
            Write-Host "==> Gone from '$($response.InstanceName)': $($response.Removed -join ', ')" -ForegroundColor $this.Colour("success")
        }
    }
}
