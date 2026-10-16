# ==============================================================================
# SELECTINSTANCE — LA VUE DU CLI
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\..\BaseViewCli.psm1
using module ..\..\MenuCli.psm1
using module ..\..\..\..\Tools\Helpers.psm1

# La question partagée : « quelle instance ? » — la même vue pour tous les
# gestes qui en ont besoin. Le contrôleur lui passe la liste (l'index qu'il a
# lu) ; le nom déjà choisi (le clic d'une ligne, le menu qui a passé la main)
# se reprend tel quel. Les lignes d'archives n'ont pas leur place ici : un
# geste d'instance ne s'y applique pas.
class CliSelectInstanceView : BaseViewCli {
    # La question, en passive : le tri, le vide et l'abandon vivent chez le
    # presenter ; ici, le menu seul — et rien quand on sort.
    [object] AskOffered([object[]]$offered) {
        $Menu = [MenuCli]::new("Our Instances")
        foreach ($row in @($offered)) {
            $null = $Menu.Add([MenuItemCli]::new(
                ("{0,-30} {1,10}" -f $row.Name, (Format-Size ($row.Size))), $row.Name))
        }
        $Picked = $Menu.Prompt()
        if ($null -eq $Picked) { return "" }
        return $Picked.Value
    }

    # Rien à choisir : le refus, peint ici — le presenter a constaté le vide
    # et sort en faute.
    [void] ShowNoInstances() {
        Write-Host ""
        Write-Host "[ABORT] No instance of this template is registered on this machine." -ForegroundColor $this.Colour("error")
        Write-Host "        Build one with  .\wsl-fleet.ps1 build" -ForegroundColor $this.Colour("hint")
    }

}
