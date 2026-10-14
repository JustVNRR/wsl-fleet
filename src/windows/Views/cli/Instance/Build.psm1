# ==============================================================================
# BUILD — LA VUE DU CLI
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewCli.psm1
using module ..\..\..\Dto\InstanceDto.psm1

# La naissance, dans l'ordre de l'ancienne : le nom, la route et sa source,
# les packs, l'onboarding, le compte, et les deux dernières questions — la
# route Dockerfile seule porte le « garder l'image ». Ask rend le BuildDto
# entier ; rien n'est écrit avant, la naissance est le seul appel.
#
# La porte du registre arrive liée au service (un pointeur de méthode) : la
# référence tapée se vérifie pendant la question, avec les mots de la porte,
# et la vue n'en sait pas plus.
class CliBuildView : BaseViewCli {
    [object] Ask([object]$sources, [object[]]$images, [object[]]$packs, [object]$checkRegistry) {
        # 1. Le nom.
        $this.ClearScreen()
        $name = $this.AskName("Name of the instance (CTRL+C to abort)", "modified")

        # 2. La route, puis sa source. Un nom de registre se vérifie sur-le-
        # champ — le refus s'affiche et la question se repose.
        $this.ClearScreen()
        $roads = @(
            [PSCustomObject]@{ Type = [WslBuildType]::Dockerfile; Label = "Dockerfile" },
            [PSCustomObject]@{ Type = [WslBuildType]::Image;      Label = "Docker image" },
            [PSCustomObject]@{ Type = [WslBuildType]::Registry;   Label = "Docker registry" }
        )
        $road = $this.AskList("Build from", $roads, { param($row) $row.Label }, "")
        if ($null -eq $road) { $this.StopCancelled("modified") }

        $buildPath = ""
        $context = ""
        $family = ""
        if ($road.Type -eq [WslBuildType]::Registry) {
            while ($true) {
                $reference = $this.AskAnswer("Docker image from a registry (e.g. alpine:latest)", "modified")
                $verdict = @($checkRegistry.Invoke(@($reference)))[0]
                if ($verdict.Valid) { $buildPath = $reference; break }
                Write-Host "  Unknown registry image '$reference' - $($verdict.Why)" -ForegroundColor $this.Colour("warning")
            }
        } else {
            $rows = if ($road.Type -eq [WslBuildType]::Image) { @($images) } else { @($sources.Dockerfiles) }
            if ($rows.Count -eq 0) {
                if ($road.Type -eq [WslBuildType]::Image) {
                    $this.Abort(@("No Docker image under 'assets\dockerimages'.", "Upload one, or pick another road.", "Nothing was modified."))
                }
                $this.Abort(@("No Dockerfile under 'assets\dockerfiles'.", "Upload one, or delete that folder to get the repository's own back.", "Nothing was modified."))
            }

            # Une seule ligne est la réponse : demander laquelle d'une, c'est du bruit.
            $picked = if ($rows.Count -eq 1) { $rows[0] } else { $this.AskList($road.Label, $rows, { param($row) $row.Name }, "") }
            if ($null -eq $picked) { $this.StopCancelled("modified") }

            $this.ClearScreen()
            $buildPath = "$($picked.Path)"
            if ($road.Type -eq [WslBuildType]::Dockerfile) {
                $context = Split-Path -Parent $buildPath
                $family = "$($picked.Family)"
            }
        }

        # 3. Les packs : la famille de la source filtre les lignes, le socle
        # se pré-coche quand elle est connue, et une famille illisible est
        # dite — les packs restent en portée. Échap ou rien coché = aucun,
        # la naissance continue.
        $packNames = @()
        if ($packs.Count -gt 0) {
            $offered = if ($family) { @($packs | Where-Object { $_.Family -eq $family }) } else { @($packs) }
            $note = if ($family) { "" } else { "This recipe's system cannot be read - a pack made for another one will fail to install." }
            $checked = @()
            for ($index = 0; $index -lt $offered.Count; $index++) {
                if ($family -and $offered[$index].Shell -and $offered[$index].Family -eq $family) { $checked += $index }
            }

            $chosen = $this.AskChecklist("Packs for '$name'", $offered, {
                param($pack)
                "{0,-12} [{1}] {2}" -f $pack.Name, $pack.Family, $pack.Description
            }, $checked, $note)
            if ($null -ne $chosen) { $packNames = @($chosen | ForEach-Object { $_.Name }) }

            if ($packNames.Count -eq 0) {
                Write-Host ""
                Write-Host "[OK] No pack selected." -ForegroundColor $this.Colour("success")
            }
        }

        # 4. L'onboarding — le premier des assets est proposé, la liste
        # choisit lequel ; sans aucun, c'est dit et la naissance continue.
        $firstBoot = ""
        $boots = @($sources.Onboardings)
        if ($boots.Count -eq 0) {
            Write-Host ""
            Write-Host "  No onboarding shell under 'assets\onboardings' - the instance will be built without one." -ForegroundColor $this.Colour("muted")
        } else {
            Write-Host ""
            if ($this.Confirm("Run the onboarding shell?", $false)) {
                $picked = $this.AskList("Onboarding shell", $boots, { param($row) $row.Name }, "")
                if ($null -eq $picked) { $this.StopCancelled("modified") }
                $firstBoot = "$($picked.Path)"
            }
        }

        # 5. Le compte : l'onboarding le crée, donc il ne se demande qu'avec
        # un onboarding — le nom Windows est proposé quand il se nettoie en un.
        $user = ""
        if ($firstBoot) {
            $proposal = "$env:USERNAME".ToLower()
            $proposal = $proposal.Normalize([Text.NormalizationForm]::FormD) -replace '\p{Mn}', ''
            $proposal = $proposal -replace '[^a-z0-9_-]+', '-'
            $proposal = $proposal.Trim('-', '_')
            if (-not ($proposal -cmatch '^[a-z][a-z0-9_-]*$')) { $proposal = "" }
            $user = $this.AskUser($name, $proposal)
        }

        # 6. Les deux dernières, tout en bas : ce que l'image de travail
        # devient (la route Dockerfile seule en a une), et Docker Desktop.
        $keep = $false
        if ($road.Type -eq [WslBuildType]::Dockerfile) {
            Write-Host ""
            $keep = $this.Confirm("Keep Docker image?", $false)
        }
        Write-Host ""
        $register = $this.Confirm("Add '$name' to Docker Desktop? (it will be restarted)", $false)

        # 7. Les réponses, dans la forme du service. L'apparence n'est pas
        # demandée ici — l'ancienne ne la demandait pas non plus : la
        # naissance pose ses défauts.
        $dto = [BuildDto]::new()
        $dto.Name = $name
        $dto.User = $user
        $dto.BuildType = $road.Type
        $dto.BuildPath = $buildPath
        $dto.Context = $context
        $dto.Onboarding = $firstBoot
        $dto.Packs = @($packNames)
        $dto.KeepImage = $keep
        $dto.RegisterDocker = $register
        return $dto
    }

    # Le compte de l'onboarding : la forme vérifiée, le nom Windows proposé
    # quand il se nettoie en un — Entrée le prend. La question ne revient pas
    # sur un refus, comme l'ancienne.
    hidden [string] AskUser([string]$name, [string]$proposal) {
        $prompt = "User name for '$name' (CTRL+C to abort)"
        if ($proposal) { $prompt = "User name for '$name' [$proposal] (CTRL+C to abort)" }
        Write-Host ""
        while ($true) {
            Write-Host -NoNewline "${prompt}: " -ForegroundColor $this.Colour("warning")
            $answer = "$(Read-Host)".Trim()
            if (-not $answer -and $proposal) { $answer = $proposal }
            # -cmatch, pas -match : PowerShell ignore la casse, et 'Root'
            # passerait ici pour être refusé dedans.
            if ($answer -cmatch '^[a-z][a-z0-9_-]*$') { return $answer }
            Write-Host "  Lowercase letters, digits, '_' and '-' only, starting with a letter." -ForegroundColor $this.Colour("hint")
        }

        # Jamais atteint — la boucle ne sort qu'en rendant ; pour l'analyseur.
        return ""
    }

    # Le verdict de la naissance : ses lignes, puis le mot de la fin.
    [void] Show([string]$name, [object]$response) {
        foreach ($message in @($response.Messages)) {
            Write-Host ""
            Write-Host "  $message" -ForegroundColor $this.Colour("muted")
        }
        Write-Host ""
        Write-Host "==> Built '$name' ($($response.Status))." -ForegroundColor $this.Colour("success")
        Write-Host ""
    }
}
