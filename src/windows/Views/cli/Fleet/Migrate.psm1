# ==============================================================================
# MIGRATE — LA VUE DU CLI
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewCli.psm1

# Le déménagement : une seule question — le dossier d'arrivée, posée avec la
# racine en main — puis l'entête et le rapport. La boucle du voyage est muette
# (elle vit au service) : c'est le rapport qui NOMME ce qui a voyagé. La vue
# ne décide plus : les deux refus qui ne coûtent rien — la cible qui est la
# racine, la cible que Test-FleetTarget refuse — sont dits, au presenter.
class CliMigrateView : BaseViewCli {
    # Le dossier d'arrivée, lu — la question et rien d'autre : le vide et les
    # refus restent au presenter.
    [string] AskTarget([string]$root) {
        Write-Host ""
        Write-Host -NoNewline "Move the fleet from '$root' to: "
        return [string](Read-Host).Trim()
    }

    # La cible qui est le dossier de travail : ce n'est pas un refus, c'est
    # dit, et rien ne bouge.
    [void] ShowSameFolder() {
        Write-Host ""
        Write-Host "  That is the working folder - nothing to move." -ForegroundColor $this.Colour("warning")
    }

    # La cible qu'on ne peut pas viser, dite.
    [void] ShowTargetProblem([string]$problem) {
        Write-Host ""
        Write-Host "  $problem" -ForegroundColor $this.Colour("warning")
    }

    # L'entête du déménagement, dit une fois le dossier connu : ce qui va se
    # passer, et ce que ça coûte — les instances qui tournent sont arrêtées
    # une par une.
    [void] ShowLead() {
        Write-Host ""
        Write-Host "==> Archiving the fleet" -ForegroundColor $this.Colour("info")
        Write-Host "  Instances that run are stopped one by one as they are archived - anything" -ForegroundColor $this.Colour("muted")
        Write-Host "  unsaved in them is lost. Docker Desktop and the others keep running." -ForegroundColor $this.Colour("muted")
    }

    # Le rapport : ce qui a voyagé — NOMMÉ — et par où ça revient. Rien à
    # emporter reste une fin, pas un refus : la ligne le dit sans noms.
    [void] Show([string]$target, [object]$moved) {
        Write-Host ""
        $names = @($moved | Where-Object { $null -ne $_ })
        if ($names.Count) {
            Write-Host "==> Moved $($names -join ', ') and the archives to '$target'." -ForegroundColor $this.Colour("success")
        } else {
            Write-Host "==> Moved the archives to '$target'." -ForegroundColor $this.Colour("success")
        }
        Write-Host "    Restore them on the other side with  .\wsl.ps1 restore" -ForegroundColor $this.Colour("muted")
        Write-Host ""
    }
}
