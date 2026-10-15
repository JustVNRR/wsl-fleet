# ==============================================================================
# BUILD — LA VUE DU CLI
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewCli.psm1
using module ..\..\..\Dto\InstanceDto.psm1

# La naissance, dans l'ordre de l'ancienne : le nom, la route et sa source,
# les packs, l'onboarding, le compte, et les deux dernières questions. La vue
# ne décide plus — les boucles, les règles et les lectures vivent au
# presenter ; ici, les menus, les questions et les lignes. Chaque question
# rend la réponse brute ; rien n'est écrit avant la fin.
class CliBuildView : BaseViewCli {
    [void] ShowNameHint() {
        Write-Host "  Letters, digits, '.', '_' and '-' only." -ForegroundColor $this.Colour("hint")
    }

    # Le nom, lu — la question et rien d'autre : le vide, la forme et l'indice
    # restent au presenter.
    [string] AskInstanceName([string]$question) {
        return [string](Read-Host $question)
    }

    # La route de la naissance : le Dockerfile, l'image montée, le registre.
    # Rendue, la ligne choisie ; rien quand on sort.
    [object] AskRoad() {
        $roads = @(
            [PSCustomObject]@{ Type = [WslBuildType]::Dockerfile; Label = "Dockerfile" },
            [PSCustomObject]@{ Type = [WslBuildType]::Image;      Label = "Docker image" },
            [PSCustomObject]@{ Type = [WslBuildType]::Registry;   Label = "Docker registry" }
        )
        $road = $this.AskList("Build from", $roads, { param($row) $row.Label }, "")
        if ($null -eq $road) { return "" }
        return $road
    }

    # La référence du registre, lue — le vide et la vérification restent au
    # presenter.
    [string] AskRegistryReference([string]$question) {
        Write-Host -NoNewline "${question}: "
        return [string](Read-Host).Trim()
    }

    # Le refus du registre, dit — le verdict vient du service.
    [void] ShowUnknownRegistry([string]$reference, [string]$why) {
        Write-Host "  Unknown registry image '$reference' - $why" -ForegroundColor $this.Colour("warning")
    }

    # Le refus d'un geste qui n'a rien à faire : la première ligne est la
    # bannière, les suivantes ses repères — mêmes phrases que l'ancien Abort,
    # sans couper personne : le presenter en tire l'ActionResult.
    [void] ShowAbort([string[]]$lines) {
        Write-Host ""
        $first = $true
        foreach ($line in @($lines)) {
            if ($first) {
                Write-Host "[ABORT] $line" -ForegroundColor $this.Colour("error")
                $first = $false
            } else {
                Write-Host "        $line" -ForegroundColor $this.Colour("hint")
            }
        }
    }

    # La source : la liste reçue, ses lignes. Rien quand on sort.
    [object] AskSource([string]$label, [object[]]$rows) {
        $picked = $this.AskList($label, @($rows), { param($row) $row.Name }, "")
        if ($null -eq $picked) { return "" }
        return $picked
    }

    # La checklist des packs : la famille filtrée et la case du socle
    # pré-cochée sont reçues ; $null quand on sort — le presenter le lit comme
    # « aucun », la naissance continue.
    [object[]] AskPacks([string]$name, [object[]]$offered, [int[]]$checked, [string]$note) {
        return $this.AskChecklist("Packs for '$name'", @($offered), {
            param($pack)
            "{0,-12} [{1}] {2}" -f $pack.Name, $pack.Family, $pack.Description
        }, @($checked), $note)
    }

    [void] ShowNoPackChosen() {
        Write-Host ""
        Write-Host "[OK] No pack selected." -ForegroundColor $this.Colour("success")
    }

    [void] ShowNoOnboarding() {
        Write-Host ""
        Write-Host "  No onboarding shell under 'assets\onboardings' - the instance will be built without one." -ForegroundColor $this.Colour("muted")
    }

    # L'onboarding : le oui d'abord, la liste ensuite — le blank et la porte
    # ensemble, comme l'ancienne.
    [bool] AskRunOnboarding() {
        Write-Host ""
        return $this.Confirm("Run the onboarding shell?", $false)
    }

    [object] AskOnboarding([object[]]$boots) {
        $picked = $this.AskList("Onboarding shell", @($boots), { param($row) $row.Name }, "")
        if ($null -eq $picked) { return "" }
        return $picked
    }

    # Le blanc d'avant la question du compte, une fois.
    [void] ShowBeforeAccount() {
        Write-Host ""
    }

    # Le compte, lu — la question et rien d'autre : le vide, la proposition et
    # la forme restent au presenter.
    [string] AskUserName([string]$prompt) {
        Write-Host -NoNewline "${prompt}: " -ForegroundColor $this.Colour("warning")
        return "$(Read-Host)".Trim()
    }

    [void] ShowUserHint() {
        Write-Host "  Lowercase letters, digits, '_' and '-' only, starting with a letter." -ForegroundColor $this.Colour("hint")
    }

    [bool] AskKeepImage() {
        Write-Host ""
        return $this.Confirm("Keep Docker image?", $false)
    }

    [bool] AskRegisterDocker([string]$name) {
        Write-Host ""
        return $this.Confirm("Add '$name' to Docker Desktop? (it will be restarted)", $false)
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
