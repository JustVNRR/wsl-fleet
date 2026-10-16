# ==============================================================================
# LES PACKS — L'OUVRIER
# ==============================================================================
# Le processus à part d'un geste long : un enfant pwsh qui rebâtit le service
# sur les dossiers reçus et fait la chose. Un runspace du même processus ne va
# pas — mesuré depuis toujours : un appel à wsl.exe hors d'un hôte ne revient
# jamais, et sous une méthode de classe un natif perd son terminal. L'enfant,
# lui, a un hôte.
#
# VISIBLE : sa console est le déroulé — le déroulé EST le log. Pas de journal,
# pas de guet : on regarde le travail défiler.
#
# Ce dont ce fichier nomme, déclaré ici : il tire ses modules lui-même. Ce
# qu'il voit : la fabrique — un service, pas ses dépôts.
using module ..\Services\ServiceFactory.psm1
using module ..\Dtos\InstanceDto.psm1

param(
    [string]$Name,
    [string]$Arg1,   # à installer, séparés par des virgules
    [string]$Arg2,   # à retirer, séparés par des virgules
    [string]$Assets,
    [string]$Root
)

$distroTree = ""
$candidate = Join-Path $PSScriptRoot "..\..\..\src\distro"
if (Test-Path $candidate) { $distroTree = (Resolve-Path $candidate).Path }

try {
    $service = [ServiceFactory]::CreateInstanceService($Root, $Assets, $distroTree)

    $dto = [ManagePacksDto]::new()
    $dto.InstanceName = $Name
    $dto.ToAdd = @($Arg1 -split ',' | Where-Object { $_ })
    $dto.ToRemove = @($Arg2 -split ',' | Where-Object { $_ })
    Write-Host "Managing the packs of '$Name'..."
    $r = $service.ManagePacks($dto)
    Write-Host "Outcome: $($r.Outcome)"
    foreach ($line in @($r.Installed)) { Write-Host "  installed: $line" }
    foreach ($line in @($r.Removed)) { Write-Host "  removed:   $line" }
    foreach ($line in @($r.Failed)) { Write-Host "  FAILED:    $line" }
    if ($r.ExitCode -ne 0) { exit 1 }
    exit 0
} catch {
    Write-Host ("FAILED: " + ($_.Exception.Message -replace "`r?`n", " "))
    exit 1
}
