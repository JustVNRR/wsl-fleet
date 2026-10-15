# ==============================================================================
# LE CONTRÔLEUR DE L'INSTANCE
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout un type qu'il a tiré
# lui-même.
using module ..\Presenters\ActionResult.psm1
using module .\BaseController.psm1
using module ..\Service\InstanceService.psm1
using module ..\Dto\InstanceDto.psm1

# Les gestes d'une instance, une méthode chacun — le même nom que celui du
# service qu'elle appelle. C'est le contrôleur qui lit : il interroge le
# service, et n'appelle les vues qu'avec des données — une vue ne connaît
# jamais le service. Il mène le flot, et quand le service refuse, le refus est
# peint par la vue d'erreur : il ne remonte pas plus loin. Ni règle métier, ni
# disque, ni wsl.exe, ni une ligne à l'écran de sa part.
#
# La résolution des vues vit dans la base (BaseController) ; ses vues à lui
# sont sous Views\<ViewType>\Instance\ :
#
#   Views\cli\Instance\shared\SelectInstance.psm1 — class CliSelectInstanceView,
#       la question du cli ; le shell (Open) n'a pas de vue non plus — il
#       s'ouvre, c'est tout.
#   Views\cli\Instance\Restart.psm1        — class CliRestartView : BaseViewCli
#   Views\cli\shared\Error.psm1            — class CliErrorView, la vue
#       d'erreur commune aux contrôleurs
#
# Une vue fait une chose. La question « quelle instance ? » a SA vue
# (SelectInstance), la même pour tous les gestes qui en ont besoin : le
# contrôleur l'affiche d'abord, puis — le nom en main — lit ce qu'il faut au
# service et affiche la vue du geste, l'instance déjà là. Les gestes à deux
# questions (les packs : l'instance, PUIS ses packs) suivent le même chemin :
# SelectInstance, une lecture, puis la vue du geste.
#
# Ce qu'une vue porte, ses méthodes :
#   Ask(...) — la question, préformatée, avec les données reçues ; elle rend
#       ce que le service prend (le Dto, ou le nom) — vide quand la vue
#       n'a rien à rendre, elle a déjà tout dit.
#   Show(...) — le rapport, quand le service a rendu. Une méthode qui ne rend
#       rien n'a rien à montrer : la porte se ferme sans donnée.
#   La vue d'erreur porte Show($Failure) — le refus de n'importe quel geste.
#
# Un geste rend un ActionResult : Ok + « Geste 'cible' », Nok + « Geste
# 'cible' - la phrase du refus », Ok + « Geste : cancelled » quand
# l'utilisateur a abandonné. L'entrée du cli en tire son code de sortie, la
# fenêtre sa ligne de trail.
#
# Les longs gestes — la naissance, retirer, compacter, archiver, restaurer,
# copier, la corbeille d'archive — se courent ICI, sur place : le cli est le
# seul monde qui passe par ce contrôleur (le gui a ses ViewModels), et il n'a
# pas de fenêtre à bloquer.
class InstanceController : BaseController {
    hidden [InstanceService]$Service

    InstanceController([InstanceService]$service, [string]$viewsRoot, [string]$viewType) : base($viewsRoot, $viewType, "Instance") {
        $this.Service = $service
    }

    # =========================================================================
    # LA LISTE
    # =========================================================================

    # Le tableau, en lignes : les instances, les archives, et les dossiers
    # laissés derrière. Qui tourne se demande ICI, une fois pour tout le
    # tableau. Rien à demander — seulement à montrer ; rien du tout, c'est un
    # refus — la vue le dit, et le geste le dit au code de sortie.
    [ActionResult] List() {
        $view = $this.GetView("List")
        try {
            $rows = @($this.Service.GetAll())
            $orphans = @($this.Service.GetOrphans())
            $running = @($this.Service.GetRunningNames())
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("List : $($_.Exception.Message)")
        }
        $view.Show($rows, $orphans, $running)
        if (($rows.Count + $orphans.Count) -eq 0) { return [ActionResult]::Nok("List : none") }
        return [ActionResult]::Ok("List : $($rows.Count + $orphans.Count) row(s)")
    }

    # =========================================================================
    # LA NAISSANCE ET LA VIE
    # =========================================================================

    # La naissance : ses questions tiennent tout (le nom, l'utilisateur, la
    # route et sa source, les packs, l'onboarding). Le contrôleur lit ce que
    # ses listes affichent — les sources (avec leur famille), le magasin, la
    # checklist — et lui passe aussi la porte du registre, liée au service :
    # la référence tapée se vérifie pendant la question, avec les mots de la
    # porte, sans que la vue connaisse le service.
    [ActionResult] Build() {
        $view = $this.GetView("Build")
        try {
            $sources = $this.Service.GetBuildSources()
            $images = @($this.Service.GetAllSavedImages())
            $packs = @($this.Service.GetBuildPacks())
            $checkRegistry = $this.Service.IsRegistryImageValid
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Build : $($_.Exception.Message)")
        }
        $dto = $view.Ask($sources, $images, $packs, $checkRegistry)
        if ($null -eq $dto) { return [ActionResult]::Ok("Build : cancelled") }

        # Le docker doit répondre avant la FABRICATION — l'ancienne sondait
        # là : le questionnaire d'abord, puis la sonde, puis la naissance.
        # Le démarrage est direct : le service ne relance rien s'il tourne
        # déjà, et son verdict décide — refusé, la naissance s'arrête dite,
        # le refus peint, au lieu de s'écraser en plein docker build (vécu
        # sur sa machine).
        if (-not ($this.Service.StartDocker())) {
            $view.Abort(@("Docker is not responding.", "Start Docker Desktop, then try again."))
            return [ActionResult]::Nok("Build : Docker is not responding.")
        }
        try {
            $response = $this.Service.Build($dto)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Build : $($dto.Name) - $($_.Exception.Message)")
        }
        $view.Show($dto.Name, $response)
        # La naissance passée, le shell qu'elle a promis s'ouvre — le cli
        # seul : la fenêtre a son ouvrier, qui fait de même à sa fin. Un
        # shell qui ne s'ouvre pas ne défait pas la naissance.
        try { $null = $this.Service.Open($dto.Name) } catch { }
        return [ActionResult]::Ok("Build : $($dto.Name)")
    }

    [ActionResult] Open([string]$instanceName) {
        $name = $this.SelectInstance($instanceName, @())
        if (-not $name) { return [ActionResult]::Ok("Open : cancelled") }
        $view = $this.GetView("Open")
        $view.Ask($name)
        try {
            $response = $this.Service.Open($name)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Open : $name - $($_.Exception.Message)")
        }
        $view.Show($name, $response)
        return [ActionResult]::Ok("Open : $name")
    }

    [ActionResult] Restart([string]$instanceName) {
        $name = $this.SelectInstance($instanceName, @())
        if (-not $name) { return [ActionResult]::Ok("Restart : cancelled") }
        $view = $this.GetView("Restart")
        $view.Ask($name)
        try {
            $response = $this.Service.Restart($name)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Restart : $name - $($_.Exception.Message)")
        }
        $view.Show($name, $response)
        return [ActionResult]::Ok("Restart : $name")
    }


    # =========================================================================
    # LE LOOK
    # =========================================================================

    [ActionResult] GetAppearance([string]$instanceName) {
        $name = $this.SelectInstance($instanceName, @())
        if (-not $name) { return [ActionResult]::Ok("GetAppearance : cancelled") }
        $view = $this.GetView("GetAppearance")
        try {
            $response = $this.Service.GetAppearance($name)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("GetAppearance : $name - $($_.Exception.Message)")
        }
        $view.Show($name, $response)
        return [ActionResult]::Ok("GetAppearance : $name")
    }

    # La visite du look : le contrôleur lit tout ce que ses questions
    # affichent — le constat (le (current) et l'avertissement du fragment),
    # les polices, les schémas, les paires de la tuile — puis la vue mène la
    # conversation et rend le Dto entier.
    [ActionResult] SetAppearance([string]$instanceName) {
        $name = $this.SelectInstance($instanceName, @())
        if (-not $name) { return [ActionResult]::Ok("SetAppearance : cancelled") }
        $view = $this.GetView("SetAppearance")
        try {
            $appearance = $this.Service.GetAppearance($name)
            $fonts = @($this.Service.GetFonts())
            # La police en place s'offre toujours, quoi qu'elle porte : sans
            # les glyphes elle est hors de la lecture des polices, et son nom
            # n'aurait nulle part ou etre marque.
            if ("$($appearance.Font)" -and $fonts -notcontains "$($appearance.Font)") {
                $fonts += "$($appearance.Font)"
            }
            $schemes = @($this.Service.GetColorSchemes())
            $pairs = @($this.Service.GetIconPairs())
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("SetAppearance : $name - $($_.Exception.Message)")
        }
        $dto = $view.Ask($name, $appearance, $fonts, $schemes, $pairs)
        if ($null -eq $dto) { return [ActionResult]::Ok("SetAppearance : cancelled") }
        try {
            $response = $this.Service.SetAppearance($dto)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("SetAppearance : $($dto.InstanceName) - $($_.Exception.Message)")
        }
        $view.Show($dto.InstanceName, $response)
        return [ActionResult]::Ok("SetAppearance : $($dto.InstanceName)")
    }

    # =========================================================================
    # LES PACKS
    # =========================================================================

    [ActionResult] GetPacks([string]$instanceName) {
        $name = $this.SelectInstance($instanceName, @())
        if (-not $name) { return [ActionResult]::Ok("GetPacks : cancelled") }
        $view = $this.GetView("GetPacks")
        try {
            $response = $this.Service.GetPacks($name)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("GetPacks : $name - $($_.Exception.Message)")
        }
        $view.Show($name, $response)
        return [ActionResult]::Ok("GetPacks : $name")
    }

    [ActionResult] AddPack([string]$instanceName) {
        $name = $this.SelectInstance($instanceName, @())
        if (-not $name) { return [ActionResult]::Ok("AddPack : cancelled") }
        $view = $this.GetView("AddPack")
        try {
            $packs = $this.Service.GetPacks($name)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("AddPack : $name - $($_.Exception.Message)")
        }
        $dto = $view.Ask($packs, $name)
        if ($null -eq $dto) { return [ActionResult]::Ok("AddPack : cancelled") }
        try {
            $response = $this.Service.AddPack($dto)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("AddPack : $($dto.InstanceName) - $($_.Exception.Message)")
        }
        $view.Show($dto.InstanceName, $response)
        return [ActionResult]::Ok("AddPack : $($dto.InstanceName)")
    }

    [ActionResult] RemovePack([string]$instanceName) {
        $name = $this.SelectInstance($instanceName, @())
        if (-not $name) { return [ActionResult]::Ok("RemovePack : cancelled") }
        $view = $this.GetView("RemovePack")
        try {
            $packs = $this.Service.GetPacks($name)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("RemovePack : $name - $($_.Exception.Message)")
        }
        $dto = $view.Ask($packs, $name)
        if ($null -eq $dto) { return [ActionResult]::Ok("RemovePack : cancelled") }
        try {
            $response = $this.Service.RemovePack($dto)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("RemovePack : $($dto.InstanceName) - $($_.Exception.Message)")
        }
        $view.Show($dto.InstanceName, $response)
        return [ActionResult]::Ok("RemovePack : $($dto.InstanceName)")
    }

    [ActionResult] ManagePacks([string]$instanceName) {
        $name = $this.SelectInstance($instanceName, @())
        if (-not $name) { return [ActionResult]::Ok("ManagePacks : cancelled") }
        $view = $this.GetView("ManagePacks")
        try {
            $packs = $this.Service.GetPacks($name)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("ManagePacks : $name - $($_.Exception.Message)")
        }
        $dto = $view.Ask($packs, $name)
        if ($null -eq $dto) { return [ActionResult]::Ok("ManagePacks : cancelled") }
        try {
            $response = $this.Service.ManagePacks($dto)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("ManagePacks : $($dto.InstanceName) - $($_.Exception.Message)")
        }
        $view.Show($dto.InstanceName, $response)
        return [ActionResult]::Ok("ManagePacks : $($dto.InstanceName)")
    }

    # =========================================================================
    # L'ARCHIVE
    # =========================================================================


    # =========================================================================
    # LES PAS PARTAGÉS
    # =========================================================================

    # La question partagée : « quelle instance ? » — sa vue choisit sur
    # l'index (lu ici quand la main ne l'a pas) ; le nom donné se reprend tel
    # quel, et sans nom il n'y a rien à prendre.
    hidden [string] SelectInstance([string]$target, [object[]]$rows) {
        if (-not $rows) { $rows = @($this.Service.GetAll()) }
        return $this.GetView("SelectInstance").Ask($rows, $target)
    }
}
