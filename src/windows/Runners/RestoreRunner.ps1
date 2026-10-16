# ==============================================================================
# RESTAURER — L'OUVRIER
# ==============================================================================
# Le processus à part d'un geste long : un enfant pwsh qui rebâtit le service
# sur les dossiers reçus et fait la chose. Un runspace du même processus ne va
# pas — mesuré depuis toujours : un appel à wsl.exe hors d'un hôte ne revient
# jamais, et sous une méthode de classe un natif perd son terminal. L'enfant,
# lui, a un hôte.
#
# CACHÉ : personne ne le regarde — le journal (%TEMP%\wsl-fleet-gui-job.log)
# dit l'étape et la fin, la fenêtre le guette.
#
# Ce dont ce fichier nomme, déclaré ici : il tire ses modules lui-même. Ce
# qu'il voit : la fabrique — un service, pas ses dépôts.
using module ..\Services\ServiceFactory.psm1
using module ..\Dtos\InstanceDto.psm1

param(
    [string]$Name,   # l'archive, par son nom
    [string]$Arg1,   # la nouvelle instance, par son nom
    [string]$Arg2,
    [string]$Assets,
    [string]$Root
)

$Log = Join-Path $env:TEMP "wsl-fleet-gui-job.log"
function Write-Stamp($Message) { $null = Add-Content -LiteralPath $Log -Value "$(Get-Date -Format HH:mm:ss) $Message" }

$distroTree = ""
$candidate = Join-Path $PSScriptRoot "..\..\..\src\distro"
if (Test-Path $candidate) { $distroTree = (Resolve-Path $candidate).Path }

try {
    $service = [ServiceFactory]::CreateInstanceService($Root, $Assets, $distroTree)

    Write-Stamp "restoring '$Name' as '$Arg1'"
    $dto = [RestoreDto]::new()
    $dto.ArchiveName = $Name
    $dto.InstanceName = $Arg1
    $built = $service.Restore($dto).InstanceName
    Write-Stamp ("RESULT OK " + $built + ": restored from '" + $Name + "'")
    exit 0
} catch {
    Write-Stamp ("RESULT FAIL " + ($_.Exception.Message -replace "`r?`n", " "))
    exit 1
}
