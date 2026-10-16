# ==============================================================================
# BUILD — LE PRESENTER
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\ActionResult.psm1
using module ..\BasePresenter.psm1
using module ..\..\Services\InstanceService.psm1
using module ..\..\Dtos\InstanceDto.psm1

# La naissance, dans l'ordre de l'ancienne : le nom, la route et sa source,
# les packs, l'onboarding, le compte, et les deux dernières questions — la
# route Dockerfile seule porte le « garder l'image ». Toutes les boucles, les
# règles et les lectures vivent ici ; la vue affiche et lit. Rien n'est écrit
# avant la fin, et la naissance est le seul appel : le Dto bâti, la sonde de
# Docker, le service, puis le shell promis. L'ActionResult est la seule
# sortie.
class BuildPresenter : BasePresenter {
    hidden [InstanceService]$Service

    BuildPresenter([InstanceService]$service, [string]$viewsRoot, [string]$viewType) : base($viewsRoot, $viewType, "Instance") {
        $this.Service = $service
    }

    [ActionResult] Run() {
        $view = $this.GetView("Build")
        try {
            $sources = $this.Service.GetBuildSources()
            $images = @($this.Service.GetAllSavedImages())
            $packs = @($this.Service.GetBuildPacks())
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Build : $($_.Exception.Message)")
        }

        # 1. Le nom : la forme vérifiée, l'indice montré, le vide qui annule.
        $view.ClearScreen()
        $name = ""
        while ($true) {
            $answer = $view.AskInstanceName("Name of the instance (CTRL+C to abort)")
            if ([string]::IsNullOrWhiteSpace($answer)) {
                $view.ShowCancelled("modified")
                return [ActionResult]::Ok("Build : cancelled")
            }
            $answer = $answer.Trim()
            if ($answer -match '^[A-Za-z0-9][A-Za-z0-9_.-]*$') { $name = $answer; break }
            $view.ShowNameHint()
        }

        # 2. La route, puis sa source. Un nom de registre se vérifie sur-le-
        # champ — le refus s'affiche et la question se repose.
        $view.ClearScreen()
        $road = $view.AskRoad()
        if (-not $road) {
            $view.ShowCancelled("modified")
            return [ActionResult]::Ok("Build : cancelled")
        }

        $buildPath = ""
        $context = ""
        $family = ""
        if ($road.Type -eq [WslBuildType]::Registry) {
            while ($true) {
                $reference = $view.AskRegistryReference("Docker image from a registry (e.g. alpine:latest)")
                if ([string]::IsNullOrWhiteSpace($reference)) {
                    $view.ShowCancelled("modified")
                    return [ActionResult]::Ok("Build : cancelled")
                }
                $verdict = $this.Service.IsRegistryImageValid($reference)
                if ($verdict.Valid) { $buildPath = $reference; break }
                $view.ShowUnknownRegistry($reference, "$($verdict.Why)")
            }
        } else {
            $rows = if ($road.Type -eq [WslBuildType]::Image) { @($images) }
                    elseif ($road.Type -eq [WslBuildType]::Recipe) { @($sources.Recipes) }
                    else { @($sources.Dockerfiles) }
            if ($rows.Count -eq 0) {
                if ($road.Type -eq [WslBuildType]::Image) {
                    $view.ShowAbort(@("No Docker image under 'assets\dockerimages'.", "Upload one, or pick another road.", "Nothing was modified."))
                    return [ActionResult]::Nok("Build : no Docker image")
                }
                if ($road.Type -eq [WslBuildType]::Recipe) {
                    $view.ShowAbort(@("No recipe under 'assets\recipes'.", "Create one with the window's + button.", "Nothing was modified."))
                    return [ActionResult]::Nok("Build : no recipe")
                }
                $view.ShowAbort(@("No Dockerfile under 'assets\dockerfiles'.", "Upload one, or delete that folder to get the repository's own back.", "Nothing was modified."))
                return [ActionResult]::Nok("Build : no Dockerfile")
            }

            # One row is the answer on the two file roads; the recipe road
            # shows its menu even for a single row - the name and the date it
            # carries are what the user came to see.
            $picked = if ($rows.Count -eq 1 -and $road.Type -ne [WslBuildType]::Recipe) { $rows[0] } else { $view.AskSource("$($road.Label)", $rows) }
            if (-not $picked) {
                $view.ShowCancelled("modified")
                return [ActionResult]::Ok("Build : cancelled")
            }

            $view.ClearScreen()
            if ($road.Type -eq [WslBuildType]::Recipe) {
                # The folder is the context; its Dockerfile is what is built.
                $context = "$($picked.Path)"
                $buildPath = Join-Path $context "Dockerfile"
                $family = "$($picked.Family)"
            } else {
                $buildPath = "$($picked.Path)"
                if ($road.Type -eq [WslBuildType]::Dockerfile) {
                    $context = Split-Path -Parent $buildPath
                    $family = "$($picked.Family)"
                }
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

            $chosen = $view.AskPacks($name, $offered, $checked, $note)
            if ($null -ne $chosen) { $packNames = @($chosen | ForEach-Object { $_.Name }) }

            if ($packNames.Count -eq 0) {
                $view.ShowNoPackChosen()
            }
        }

        # 4. L'onboarding — le premier des assets est proposé, la liste
        # choisit lequel ; sans aucun, c'est dit et la naissance continue.
        $onboarding = ""
        $boots = @($sources.Onboardings)
        if ($boots.Count -eq 0) {
            $view.ShowNoOnboarding()
        } else {
            if ($view.AskRunOnboarding($road.Type -eq [WslBuildType]::Recipe)) {
                $picked = $view.AskOnboarding($boots)
                if (-not $picked) {
                    $view.ShowCancelled("modified")
                    return [ActionResult]::Ok("Build : cancelled")
                }
                $onboarding = "$($picked.Path)"
            }
        }

        # 5. Le compte : l'onboarding le crée, donc il ne se demande qu'avec
        # un onboarding — le nom Windows est proposé quand il se nettoie en un.
        $user = ""
        if ($onboarding) {
            $proposal = "$env:USERNAME".ToLower()
            $proposal = $proposal.Normalize([Text.NormalizationForm]::FormD) -replace '\p{Mn}', ''
            $proposal = $proposal -replace '[^a-z0-9_-]+', '-'
            $proposal = $proposal.Trim('-', '_')
            if (-not ($proposal -cmatch '^[a-z][a-z0-9_-]*$')) { $proposal = "" }

            $prompt = "User name for '$name' (CTRL+C to abort)"
            if ($proposal) { $prompt = "User name for '$name' [$proposal] (CTRL+C to abort)" }
            $view.ShowBeforeAccount()
            while ($true) {
                $answer = $view.AskUserName($prompt)
                if (-not $answer -and $proposal) { $answer = $proposal }
                # -cmatch, pas -match : PowerShell ignore la casse, et 'Root'
                # passerait ici pour être refusé dedans.
                if ($answer -cmatch '^[a-z][a-z0-9_-]*$') { $user = $answer; break }
                $view.ShowUserHint()
            }
        }

        # 6. Les deux dernières, tout en bas : ce que l'image de travail
        # devient (la route Dockerfile seule en a une), et Docker Desktop.
        $keep = $false
        if ($road.Type -in @([WslBuildType]::Dockerfile, [WslBuildType]::Recipe)) {
            $keep = $view.AskKeepImage()
        }
        $register = $view.AskRegisterDocker($name)

        # 7. Les réponses, dans la forme du service. L'apparence n'est pas
        # demandée ici — la naissance pose ses défauts.
        $dto = [BuildDto]::new()
        $dto.Name = $name
        $dto.User = $user
        $dto.BuildType = $road.Type
        $dto.BuildPath = $buildPath
        $dto.Context = $context
        $dto.Onboarding = $onboarding
        $dto.Packs = @($packNames)
        $dto.KeepImage = $keep
        $dto.RegisterDocker = $register

        # Le docker doit répondre avant la FABRICATION — l'ancienne sondait
        # là : le questionnaire d'abord, puis la sonde, puis la naissance.
        # Le démarrage est direct : le service ne relance rien s'il tourne
        # déjà, et son verdict décide — refusé, la naissance s'arrête dite,
        # le refus peint, au lieu de s'écraser en plein docker build (vécu
        # sur sa machine).
        if (-not ($this.Service.StartDocker())) {
            $view.ShowAbort(@("Docker is not responding.", "Start Docker Desktop, then try again."))
            return [ActionResult]::Nok("Build : Docker is not responding.")
        }
        try {
            $response = $this.Service.Build($dto)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Build : $($dto.Name) - $($_.Exception.Message)")
        }
        $view.Show($response)
        # La naissance passée, le shell qu'elle a promis s'ouvre — le cli
        # seul : la fenêtre a son ouvrier, qui fait de même à sa fin. Un
        # shell qui ne s'ouvre pas ne défait pas la naissance.
        try { $null = $this.Service.Open($dto.Name) } catch { }
        return [ActionResult]::Ok("Build : $($dto.Name)")
    }
}
