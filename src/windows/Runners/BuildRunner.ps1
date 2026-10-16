# ==============================================================================
# LA NAISSANCE — L'OUVRIER
# ==============================================================================
# Le processus à part d'un geste long : un enfant pwsh qui rebâtit le service
# sur les dossiers reçus et fait la chose. Un runspace du même processus ne va
# pas — mesuré depuis toujours : un appel à wsl.exe hors d'un hôte ne revient
# jamais, et sous une méthode de classe un natif perd son terminal. L'enfant,
# lui, a un hôte.
#
# VISIBLE : sa console est le déroulé — le déroulé EST le log. La fenêtre le
# guette quand même : sa fin relit la liste, la nouvelle instance s'y montre.
#
# Le Dto voyage en clair dans un fichier que la fenêtre a écrit (le dessin,
# les listes : trop pour une ligne de commande) : on le relit champ par
# champ, et il disparaît.
#
# Ce dont ce fichier nomme, déclaré ici : il tire ses modules lui-même. Ce
# qu'il voit : la fabrique — un service, pas ses dépôts.
using module ..\Services\ServiceFactory.psm1
using module ..\Dtos\InstanceDto.psm1

param(
    [string]$Name,
    [string]$Arg1,   # le fichier du Dto, en clair
    [string]$Arg2,
    [string]$Assets,
    [string]$Root
)

$distroTree = ""
$candidate = Join-Path $PSScriptRoot "..\..\..\src\distro"
if (Test-Path $candidate) { $distroTree = (Resolve-Path $candidate).Path }

try {
    $raw = [System.IO.File]::ReadAllText($Arg1) | ConvertFrom-Json
    Remove-Item -LiteralPath $Arg1 -ErrorAction SilentlyContinue

    $dto = [BuildDto]::new()
    $dto.Name = "$($raw.Name)"
    $dto.User = "$($raw.User)"
    $dto.BuildType = [WslBuildType]"$($raw.BuildType)"
    $dto.BuildPath = "$($raw.BuildPath)"
    $dto.Context = "$($raw.Context)"
    $dto.Onboarding = "$($raw.Onboarding)"
    $dto.Packs = @($raw.Packs | Where-Object { $_ } | ForEach-Object { "$_" })
    $dto.KeepImage = [bool]$raw.KeepImage
    $dto.RegisterDocker = [bool]$raw.RegisterDocker

    $service = [ServiceFactory]::CreateInstanceService($Root, $Assets,$distroTree)

    Write-Host "Creating '$($dto.Name)'..."
    $r = $service.Build($dto)
    foreach ($line in @($r.Messages)) { Write-Host "$line" }
    if ("$($r.Status)" -notin @("Ok", "Warning")) { exit 1 }

    # La naissance passée, le shell qu'elle a promis s'ouvre — le cli fait de
    # même de son côté. Un shell qui ne s'ouvre pas ne défait pas la naissance.
    try {
        Write-Host "Opening a shell into '$($dto.Name)'..."
        $null = $service.Open($dto.Name)
    } catch {
        Write-Host "The shell window could not be opened: $($_.Exception.Message)"
    }
    exit 0
} catch {
    Write-Host ("FAILED: " + ($_.Exception.Message -replace "`r?`n", " "))
    exit 1
}
