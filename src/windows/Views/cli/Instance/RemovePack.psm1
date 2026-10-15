# ==============================================================================
# REMOVEPACK — LA VUE DU CLI
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewCli.psm1

class CliRemovePackView : BaseViewCli {
    # La vue ne décide plus : les listes lues au service, le vide constaté, le
    # oui relu et le Dto bâti sont au presenter — ici, les lignes, la question
    # et la porte.

    # Rien porté : la réponse, dite.
    [void] ShowNoPacks([string]$name) {
        Write-Host ""
        Write-Host "[OK] '$name' carries no pack - there is nothing to remove." -ForegroundColor $this.Colour("success")
    }

    # Rien de retirable à la main : un invisible part avec le dernier qui le
    # requiert, il n'est jamais offert — la réponse, dite.
    [void] ShowNoRemovable([string]$name) {
        Write-Host ""
        Write-Host "[OK] '$name' carries no pack you choose or remove by hand." -ForegroundColor $this.Colour("success")
    }

    # Le pack, choisi : les retirables reçus, leurs lignes. Rien quand on sort
    # — le presenter le lit comme un abandon.
    [object] AskPack([string]$name, [object[]]$offered) {
        $PackName = $this.AskList("Packs installed in '$name':", @($offered), {
            param($Entry)
            [string]$Entry
        }, "")
        if (-not $PackName) { return "" }
        return "$PackName"
    }

    # La porte : le dernier moment, la ligne et la question. Ce que la réponse
    # veut dire reste au presenter.
    [bool] AskRemoval([string]$packName) {
        Write-Host ""
        return $this.Confirm("Remove '$packName'?", $false)
    }

    # Les avis du geste qui part.
    [void] ShowRemoving([string]$packName, [string]$name) {
        Write-Host ""
        Write-Host "==> Removing '$packName' from '$name'..." -ForegroundColor $this.Colour("info")
    }

    # Le rapport : le déroulé du service. Ce qui partait avec le pack, les
    # packs sans remove.sh et le ménage des dépendances n'ont plus de source —
    # la réponse ne porte que l'issue, le code et les dépendants.
    [void] Show([string]$name, [object]$response) {
        # A pack a still-installed pack requires does not leave: the removal
        # would break what stays.
        if ($response.Outcome -eq "conflict") {
            Write-Host ""
            Write-Host ("[ABORT] A pack cannot be removed while these still require it: {0}." -f ($response.Dependents -join " and ")) -ForegroundColor $this.Colour("error")
            Write-Host ("        Take {0} out first, or leave this one where it is." -f ($response.Dependents -join " and ")) -ForegroundColor $this.Colour("hint")
            Write-Host ""
            return
        }

        # The folder stays when the script failed: the pack is still half in
        # place, and its files are what a second attempt needs.
        if ($response.Outcome -eq "self-failed") {
            Write-Host ""
            Write-Host "[FAIL] The pack could not remove itself (exit code $($response.ExitCode))." -ForegroundColor $this.Colour("error")
            Write-Host "       Nothing was deleted: it is still installed in '$name'." -ForegroundColor $this.Colour("hint")
            Write-Host ""
            return
        }

        if ($response.Outcome -eq "folder-failed") {
            Write-Host ""
            Write-Host "[FAIL] The pack's folder could not be deleted (exit code $($response.ExitCode))." -ForegroundColor $this.Colour("error")
            Write-Host "       It is out of the gmake menu, but its files are still in '$name'." -ForegroundColor $this.Colour("warning")
            Write-Host ""
            return
        }

        Write-Host ""
        Write-Host "The pack was successfully uninstalled." -ForegroundColor $this.Colour("success")
    }
}
