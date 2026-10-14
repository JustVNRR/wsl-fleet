# ==============================================================================
# LE MIGRATE — L'OUVRIER
# ==============================================================================
# Le processus à part d'un geste long : un enfant pwsh qui rebâtit le service
# sur les dossiers reçus et fait la chose. Un runspace du même processus ne va
# pas — mesuré depuis toujours : un appel à wsl.exe hors d'un hôte ne revient
# jamais, et sous une méthode de classe un natif perd son terminal. L'enfant,
# lui, a un hôte.
#
# CACHÉ : personne ne le regarde — le journal (%TEMP%\wsl-stack-gui-job.log)
# dit l'étape et la fin, la fenêtre le guette (sa bande suit le voyage : les
# instances s'archivent et se désinscrivent une par une, les archives
# voyagent, la racine s'écrit).
#
# Ce dont ce fichier nomme, déclaré ici : il tire ses modules lui-même. Ce
# qu'il voit : la fabrique — une flotte, pas ses dépôts.
using module ..\Service\ServiceFactory.psm1

param(
    [string]$Name,   # le dossier d'arrivée
    [string]$Arg1,
    [string]$Arg2,
    [string]$Assets,
    [string]$Root
)

$Log = Join-Path $env:TEMP "wsl-stack-gui-job.log"
function Write-Stamp($Message) { $null = Add-Content -LiteralPath $Log -Value "$(Get-Date -Format HH:mm:ss) $Message" }

$distroTree = ""
$candidate = Join-Path $PSScriptRoot "..\..\..\src\distro"
if (Test-Path $candidate) { $distroTree = (Resolve-Path $candidate).Path }

try {
    $fleet = [ServiceFactory]::CreateFleetService($Root, $Assets, $distroTree)

    Write-Stamp "moving the fleet to '$Name'"
    $r = $fleet.Migrate($Name)
    $count = @($r.Moved).Count
    $what = if ($count -eq 0) { "the archives" } else { ($r.Moved -join ', ') + " and the archives" }
    Write-Stamp ("RESULT OK moved " + $what + " to '" + $r.Target + "'")
    exit 0
} catch {
    Write-Stamp ("RESULT FAIL " + ($_.Exception.Message -replace "`r?`n", " "))
    exit 1
}
