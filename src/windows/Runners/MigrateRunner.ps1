# ==============================================================================
# LE MIGRATE — L'OUVRIER
# ==============================================================================
# Le processus à part d'un geste long : un enfant pwsh qui rebâtit le service
# sur les dossiers reçus et fait la chose. Un runspace du même processus ne va
# pas — mesuré depuis toujours : un appel à wsl.exe hors d'un hôte ne revient
# jamais, et sous une méthode de classe un natif perd son terminal. L'enfant,
# lui, a un hôte.
#
# VISIBLE : sa console est le déroulé — le déroulé EST le log. Pas de journal,
# pas de guet : le voyage s'écrit dans la console qui le regarde, et la
# fenêtre (qui guette la console, elle) relit la flotte à sa sortie.
#
# Ce dont ce fichier nomme, déclaré ici : il tire ses modules lui-même. Ce
# qu'il voit : la fabrique — une flotte, pas ses dépôts.
using module ..\Services\ServiceFactory.psm1

param(
    [string]$Name,   # le dossier d'arrivée
    [string]$Arg1,
    [string]$Arg2,
    [string]$Assets,
    [string]$Root
)

$distroTree = ""
$candidate = Join-Path $PSScriptRoot "..\..\..\src\distro"
if (Test-Path $candidate) { $distroTree = (Resolve-Path $candidate).Path }

try {
    $fleet = [ServiceFactory]::CreateFleetService($Root, $Assets, $distroTree)

    Write-Host "Moving the fleet to '$Name'..."
    $r = $fleet.Migrate($Name)
    $count = @($r.Moved).Count
    $what = if ($count -eq 0) { "the archives" } else { ($r.Moved -join ', ') + " and the archives" }
    Write-Host "Moved $what to '$($r.Target)'."
    Write-Host "Restore them on the other side with  .\wsl-fleet.ps1 restore"
    exit 0
} catch {
    Write-Host ("FAILED: " + ($_.Exception.Message -replace "`r?`n", " "))
    exit 1
}
