# ==============================================================================
# L'INSTANCE — LE SERVICE
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout un type qu'il a tiré
# lui-même.
using module ..\Model\WslInstance.psm1
using module ..\Model\WslTheme.psm1
using module ..\Model\WslPack.psm1
using module ..\Model\WslPackCatalog.psm1
using module ..\Dto\InstanceDto.psm1
using module ..\Dto\DockerDto.psm1
using module ..\Repository\InstanceRepository.psm1
using module ..\Repository\ArchiveRepository.psm1
using module ..\Repository\WslRepository.psm1
using module ..\Repository\TerminalRepository.psm1
using module ..\Repository\DockerRepository.psm1
using module ..\Repository\PackCatalogRepository.psm1
using module ..\Repository\ConfigRepository.psm1
using module ..\Mapper\InstanceMapper.psm1
using module ..\Tools\Helpers.psm1

# Tout ce qui agit sur une instance. La règle : méthode Xxx → XxxDto en
# entrée, XxxResponseDto en retour — quand il y a quelque chose à porter :
# sans paramètre, pas de Dto ; sans retour, pas de ResponseDto. Le service
# reçoit ce qui a été choisi, il agit, il rend un DTO ou jette ; pas une
# ligne à l'écran. Et pas de pré-contrôle (« est-ce pris ? ») : les gestes
# refusent, tell don't ask. Il compose ses mondes — le registre et wsl.exe,
# les dossiers des instances et leurs archives, Terminal, Docker, le
# catalogue — et ne parle à personne d'autre.
class InstanceService {
    hidden [InstanceRepository]$Instances
    hidden [ArchiveRepository]$Archives
    hidden [WslRepository]$Wsl
    hidden [TerminalRepository]$Terminal
    hidden [DockerRepository]$Docker
    hidden [PackCatalogRepository]$Packs
    hidden [ConfigRepository]$Config
    hidden [InstanceMapper]$Map

    InstanceService([InstanceRepository]$instances, [ArchiveRepository]$archives, [WslRepository]$wsl,
                    [TerminalRepository]$terminal, [DockerRepository]$docker, [PackCatalogRepository]$packs,
                    [ConfigRepository]$config) {
        $this.Instances = $instances
        $this.Archives = $archives
        $this.Wsl = $wsl
        $this.Terminal = $terminal
        $this.Docker = $docker
        $this.Packs = $packs
        $this.Config = $config
        $this.Map = [InstanceMapper]::new()
    }

    # La racine redite après un migrate : les deux dépôts qui la portent
    # suivent — sinon la liste lit l'ancienne pour toujours (vécu : la
    # restauration invisible jusqu'au redémarrage).
    [void] ReRoot([string]$root) {
        $this.Instances.ReRoot($root)
        $this.Archives.ReRoot($root)
    }

    # =========================================================================
    # L'INDEX ET SES LECTURES
    # =========================================================================

    # L'index : les instances et les archives — le registre et le marqueur d'un
    # côté, le dossier des archives de l'autre. Chaque ligne est ce qu'on
    # affiche, et rien de plus.
    [WslIndexDto[]] GetAll() {
        $rows = @()

        # L'état Docker de toutes les lignes, lu d'un coup — une lecture pour
        # l'index entier. « unknown » (Docker Desktop absent ou illisible)
        # n'est pas « no » : la fenêtre saura quel bouton offrir.
        $dockerNames = $this.Docker.GetDesktopNames()

        foreach ($distro in @($this.Wsl.GetAllDistros())) {
            $name = $distro.GetName()
            if (-not $this.Instances.HasMarker($name)) { continue }
            $distro.SetSize($this.Instances.GetVhdxSize($name))
            $row = $this.Map.ToIndexDto($distro)
            $row.Docker = if ($null -eq $dockerNames) { "unknown" }
                          elseif ($dockerNames -contains $name) { "yes" }
                          else { "no" }
            $row.Path = $this.Instances.GetFolder($name)
            $rows += $row
        }

        foreach ($archive in @($this.Archives.GetAllArchives())) {
            $archive.SetSize($this.Archives.GetTarSize($archive.GetName()))
            $row = $this.Map.ToIndexDto($archive)
            $row.Path = $this.Archives.GetFolder($archive.GetName())
            $row.Archived = $this.Archives.GetCreatedAt($archive.GetName()).ToString("yyyy-MM-dd HH:mm")
            $rows += $row
        }

        return @($rows)
    }

    # Par le nom — la seule clé : une instance n'a pas d'identifiant, et
    # l'archive porte le sien, suffixé. Rien quand rien ne le porte.
    [WslIndexDto] GetByName([string]$name) {
        foreach ($distro in @($this.Wsl.GetAllDistros())) {
            if ($distro.GetName() -ne $name) { continue }
            if (-not $this.Instances.HasMarker($name)) { return $null }
            $distro.SetSize($this.Instances.GetVhdxSize($name))
            return $this.Map.ToIndexDto($distro)
        }

        foreach ($archive in @($this.Archives.GetAllArchives())) {
            if ($archive.GetName() -ne $name) { continue }
            $archive.SetSize($this.Archives.GetTarSize($name))
            return $this.Map.ToIndexDto($archive)
        }

        return $null
    }

    # Les dossiers marqués que personne ne revendique — ce qu'une suppression
    # interrompue, ou un wsl --unregister venu d'ailleurs, laisse derrière :
    # le marqueur est là, aucune inscrite ne vit dedans. Nom, dossier, taille ;
    # l'index ne les porte pas — aucune commande ne les retire, une main le
    # fait.
    [WslOrphanDto[]] GetOrphans() {
        # Ce que les inscrites revendiquent : leur dossier au registre, quand
        # c'est bien une des nôtres qui l'habite — le marqueur demandé là où
        # le registre dit qu'elles vivent, pas sous notre racine.
        $claimed = @()
        foreach ($distro in @($this.Wsl.GetAllDistros())) {
            $folder = $this.Wsl.GetFolder($distro.GetName())
            if (-not $folder) { continue }
            if (-not $this.Instances.HasMarkerIn($folder)) { continue }
            $claimed += $folder.TrimEnd('\')
        }

        $rows = @()
        foreach ($name in @($this.Instances.GetMarkedFolders())) {
            if ($claimed -contains $this.Instances.GetFolder($name)) { continue }
            $dto = [WslOrphanDto]::new()
            $dto.Name = $name
            $dto.Path = $this.Instances.GetFolder($name)
            $dto.Size = $this.Instances.GetVhdxSize($name)
            $rows += $dto
        }
        return @($rows)
    }

    # Qui tourne, à l'instant — la question vivante, posée là où il faut : la
    # liste la montre une fois pour tout le tableau, les gestes la posent au
    # moment d'agir. Rien ne la garde.
    [string[]] GetRunningNames() {
        return @($this.Wsl.GetRunningNames())
    }

    # =========================================================================
    # LA NAISSANCE ET LA VIE
    # =========================================================================

    # Ce depuis quoi on construit : les Dockerfiles et les onboardings
    # présents sous les assets. Le dépôt rend le brut ; la mise en forme se
    # fait ici — le nom du dossier sans son hash final, la date du fichier
    # entre parenthèses, « ubuntu-dev (08/10 21:34) », et le tri. La route
    # image s'en sert aussi, par le magasin.
    [GetBuildSourcesResponseDto] GetBuildSources() {
        $response = [GetBuildSourcesResponseDto]::new()
        $response.Dockerfiles = @($this.FormatSourceRows(@($this.Config.GetDockerfiles())))
        $response.Onboardings = @($this.FormatSourceRows(@($this.Config.GetOnboardings())))
        return $response
    }

    # Les lignes d'une liste de sources, mises en forme : le nom sans son hash
    # final, la date du fichier à l'ancien format d'écran, triées — et la
    # famille quand la lecture la porte (un Dockerfile, pas un onboarding).
    hidden [WslBuildSourceDto[]] FormatSourceRows([object[]]$rows) {
        $out = @()
        foreach ($row in @($rows | Sort-Object Name)) {
            $dto = [WslBuildSourceDto]::new()
            $dto.Name = "$($row.Name -replace '-[0-9a-f]{8}$', '') ($($row.Modified.ToString("dd'/'MM HH:mm")))"
            $dto.Path = "$($row.Path)"
            $dto.Family = "$($row.Family)"
            $dto.Uploaded = ("$($row.Name)" -match '-[0-9a-f]{8}$')
            $out += $dto
        }
        return @($out)
    }

    # Une recette téléversée : le dépôt la copie dans son emplacement, et le
    # service met la ligne en forme — le nom d'écran, le chemin, la famille
    # lue au FROM pour un Dockerfile. La ligne rendue se pose telle quelle
    # dans la liste de la fenêtre.
    [WslBuildSourceDto] UploadRecipe([UploadRecipeDto]$dto) {
        $target = $this.Config.CopyRecipe($dto.Kind, $dto.Source, $dto.FileName)
        $row = [PSCustomObject]@{
            Name     = (Split-Path -Path (Split-Path -Path $target -Parent) -Leaf)
            Path     = $target
            Modified = (Get-Item -LiteralPath $target).LastWriteTime
            Family   = if ($dto.FileName -eq "Dockerfile") { $this.Config.ReadRecipeFamily($target) } else { "" }
        }
        return @($this.FormatSourceRows(@($row)))[0]
    }

    # Docker répond-il — la sonde que le contrôleur lit avant la naissance.
    [bool] TestDocker() {
        return $this.Docker.TestRunning()
    }

    # Docker Desktop lancé au besoin — déjà debout, l'appel ne lance rien et
    # rend vrai ; le contrôleur l'appelle directement avant de fabriquer.
    [bool] StartDocker() {
        if ($this.Docker.TestRunning()) { return $true }
        return $this.Docker.StartDesktop()
    }

    # Un emplacement de recette ôté — le dépôt le retire, et rien d'autre :
    # un chemin hors des recettes jette là-bas.
    [void] DeleteRecipe([string]$path) {
        $this.Config.RemoveRecipe($path)
    }

    # Une recette rendue où l'utilisateur pointe.
    [void] ExportRecipe([ExportRecipeDto]$dto) {
        $this.Config.ExportRecipe($dto.Path, $dto.Target)
    }

    # Les packs que la naissance peut offrir : les offerts du catalogue, avec
    # leur famille et la marque du socle — oh_my_shell, la case que la
    # checklist pré-coche quand la famille de la source se lit et colle.
    [WslBuildPackDto[]] GetBuildPacks() {
        $rows = @()
        foreach ($pack in @($this.ReadCatalog().OfferedFor(""))) {
            $dto = [WslBuildPackDto]::new()
            $dto.Name = $pack.GetName()
            $dto.Family = $pack.GetFamily()
            $dto.Description = $pack.GetDescription()
            $dto.Shell = ($pack.GetName() -eq "oh_my_shell")
            $rows += $dto
        }
        return @($rows)
    }

    # La naissance, du Dto à l'instance complète : l'image (route par route),
    # le rootfs exporté et importé, le marqueur, l'onboarding joué ou le
    # compte de l'image lu, le look posé, les packs choisis, l'image de
    # travail gardée ou rendue, Docker Desktop — et le verdict, jamais jeté :
    # ce qui n'a pas pu s'appliquer se dit dans la réponse, une instance née
    # avec un shell nu vaut mieux que pas d'instance. Un nom déjà inscrit, un
    # dossier déjà pris, une image qui échoue : là, la naissance jette.
    [BuildResponseDto] Build([BuildDto]$dto) {
        $name = $dto.Name
        $user = $dto.User

        foreach ($distro in @($this.Wsl.GetAllDistros())) {
            if ($distro.GetName() -eq $name) { throw "An instance named '$name' is registered on this machine." }
        }
        if ($this.Instances.IsFolderOccupied($name)) {
            throw "Installation folder '$($this.Instances.GetFolder($name))' already exists and is not empty."
        }

        # L'image : une Dockerfile se construit (le tag de travail), une image
        # montée se charge (son nom à elle), une référence de registre passe
        # telle quelle.
        $tag = "wsl-stack:$name"
        $imageRef = $dto.BuildPath
        if ($dto.BuildType -eq [WslBuildType]::Dockerfile) {
            $this.Docker.Build($tag, $dto.BuildPath, $dto.Context)
            $imageRef = $tag
        } elseif ($dto.BuildType -eq [WslBuildType]::Image) {
            $imageRef = $this.Docker.Load($dto.BuildPath)
        }

        # Le rootfs, puis l'import. Une naissance qui n'enregistre pas ne
        # laisse pas de dossier derrière elle.
        $installPath = $this.Instances.GetFolder($name)
        $tarPath = Join-Path (Split-Path $installPath -Parent) "$name-rootfs.tar"
        try {
            $this.Docker.ExportRootfs($imageRef, $tarPath)
            if (-not (Test-Path $installPath)) { $null = New-Item -ItemType Directory -Path $installPath -Force }
            $this.Wsl.Import($name, $installPath, $tarPath)
        } catch {
            Remove-Item -Recurse -Force $installPath -ErrorAction SilentlyContinue
            throw
        } finally {
            Remove-Item $tarPath -Force -ErrorAction SilentlyContinue
        }

        # À nous à partir d'ici, quoi qu'il arrive — écrit avant le look, qui
        # peut encore échouer : une naissance qui s'arrête plus loin laisse une
        # instance réelle, pas une invisible.
        $this.Instances.WriteMarker($name, "build")

        $instance = [WslInstance]::new()
        $instance.SetName($name)
        $instance.SetDefaultUser($user)
        $theme = [WslTheme]::Default($name)
        if ($dto.Font) { $theme.SetFont($dto.Font) }
        if ($dto.ColourScheme) { $theme.SetColourScheme($dto.ColourScheme) }
        if ($dto.Icon) { $theme.SetIcon($dto.Icon) }
        $instance.SetTheme($theme)

        # L'onboarding du Dto, quand il en nomme un : posé, joué en root avec
        # le nom du compte, puis la distribution arrêtée pour que la prochaine
        # ouverture lise le compte qu'il a fait. Sans lui, l'image se garde
        # telle quelle : qui ouvre l'instance est ce que son /etc/wsl.conf dit.
        if ($dto.Onboarding) {
            $this.Wsl.SaveFirstBootScript($name, $dto.Onboarding)
            $this.Wsl.RunFirstBoot($name, $user)
            $this.Wsl.Terminate($name)
        } else {
            $imageUser = ""
            foreach ($line in @($this.Wsl.GetInInstance($name, @("cat", "/etc/wsl.conf")))) {
                if ("$line" -match '^\s*default\s*=\s*(\S+)\s*$') { $imageUser = $Matches[1]; break }
            }
            if (-not $imageUser) { $imageUser = "root" }
            $instance.SetDefaultUser($imageUser)
        }

        # Le look — essayé, jamais dû.
        $warnings = @()
        try {
            $warnings += @($this.ApplyLook($name, $instance))
        } catch {
            $warnings += "the look failed: $($_.Exception.Message)"
        }

        # L'image de travail, le mot du Dto : gardée en tar quand il l'a
        # demandé (la route image la recharge en secondes), et son tag rendu
        # dans tous les cas — plus rien n'en a besoin. Au mieux : une naissance
        # ne meurt pas de ses restes.
        if ($dto.BuildType -eq [WslBuildType]::Dockerfile) {
            if ($dto.KeepImage) {
                $savePath = $this.Docker.GetSavedImagePath($name)
                if (-not $this.Docker.SaveImage($tag, $savePath)) {
                    $warnings += "the image could not be saved to '$savePath'."
                }
            }
            $null = $this.Docker.RemoveImage($tag)
        }

        # Docker Desktop, le dernier acte : l'écriture et le redémarrage sont
        # dus (l'inscription était le mot de l'appelant), le verdict est à la
        # naissance — le client s'injecte au rythme de Docker.
        if ($dto.RegisterDocker) {
            $this.RegisterDockerDesktop($name)
            $warnings += @($this.WaitDockerClient($name))
        }

        # Les packs choisis, le dernier pas, au mieux : un échec est une note
        # sur la réponse, jamais une naissance ratée.
        if (@($dto.Packs).Count -gt 0) {
            try {
                $warnings += @($this.InstallChosenPacks($name, @($dto.Packs)))
            } catch {
                $warnings += "not installed - $($_.Exception.Message)"
            }
        }

        $response = [BuildResponseDto]::new()
        $response.InstanceName = $name
        $response.Status = if ($warnings.Count -gt 0) { [WslRecipeStatus]::Warning } else { [WslRecipeStatus]::Ok }
        $response.Messages = @($warnings)
        return $response
    }

    # Le shell : une fenêtre part, rien n'est attendu. Le Dto dit si le
    # profil Terminal l'a portée, ou si c'est la console nue — le repli quand
    # aucun profil ne répond.
    [OpenResponseDto] Open([string]$instanceName) {
        $response = [OpenResponseDto]::new()
        $response.InstanceName = $instanceName
        if ($this.Terminal.HasWslProfile($instanceName)) {
            $this.Terminal.TouchSettings()
            $this.Wsl.OpenProfile($instanceName)
            $response.Profile = $true
            return $response
        }
        $this.Wsl.OpenBareShell($instanceName)
        $response.Profile = $false
        return $response
    }

    # L'arrêt, puis le départ. Une moitié qui échoue jette avec la moitié
    # nommée et l'état où l'instance reste : personne ne voit dedans, et
    # deviner n'est pas le métier d'ici.
    [RestartResponseDto] Restart([string]$instanceName) {
        try {
            $this.Wsl.Terminate($instanceName)
        } catch {
            throw "The stop did not complete - '$instanceName' may still be running, and was not started again. $($_.Exception.Message)"
        }
        try {
            $this.Wsl.Start($instanceName)
        } catch {
            throw "The start did not complete - '$instanceName' is stopped. $($_.Exception.Message)"
        }
        $response = [RestartResponseDto]::new()
        $response.InstanceName = $instanceName
        return $response
    }

    # La destruction : l'archivage d'abord sur le oui, puis le
    # désenregistrement — la porte a déjà demandé. Un archivage raté arrête
    # tout, et le dit : rien de l'instance n'a été touché.
    [void] Remove([RemoveDto]$dto) {
        $name = $dto.InstanceName

        if ($dto.ArchiveFirst) {
            try {
                $null = $this.Archive($this.ArchiveDtoFor($name))
            } catch {
                throw "The archive did not complete - nothing was destroyed. $($_.Exception.Message)"
            }
        }

        $this.Wsl.TerminateQuietly($name)
        $this.Wsl.Unregister($name)
        $this.Instances.RemoveFolder($name)

        # Les traces Windows : les entrées du settings.json de l'utilisateur
        # que ce nom orpheline, notre propre fragment, et ceux qui pointent un
        # guid mort — la distribution est partie.
        $fragments = $this.Terminal.GetWslGuids($name)
        $null = $this.Terminal.PruneGhostEntries($name, @($fragments.Guids))
        $this.Terminal.DeleteFragment($name)
        $null = $this.Terminal.RemoveStaleFragments(@($fragments.Guids))

        try {
            # Un fichier de Docker Desktop qui ne se lit pas ne défait pas un
            # désenregistrement déjà fait.
            $this.Docker.RemoveDesktopState($name)
        } catch { }
    }

    # La compacité : l'archivage d'abord sur le oui, le disque repris ensuite,
    # en place. Une instance qui tournait est remise en route — au mieux.
    [CompactResponseDto] Compact([CompactDto]$dto) {
        $name = $dto.InstanceName
        $archived = $false

        if ($dto.ArchiveFirst) {
            try {
                $null = $this.Archive($this.ArchiveDtoFor($name))
            } catch {
                throw "The archive did not complete - nothing was compacted: $($_.Exception.Message)"
            }
            $archived = $true
        }

        $wasRunning = @($this.Wsl.GetRunningNames()) -contains $name

        # Les tailles, mesurées ici : ce que le disque pesait avant, ce qu'il
        # pèse après, et ce qu'il a rendu — la vue n'a rien à calculer.
        $sizeBefore = $this.Instances.GetVhdxSize($name)
        $this.Wsl.Compact($name)
        $sizeAfter = $this.Instances.GetVhdxSize($name)

        $restarted = $false
        if ($wasRunning) {
            try { $this.Wsl.Start($name); $restarted = $true } catch { }
        }

        $response = [CompactResponseDto]::new()
        $response.InstanceName = $name
        $response.Archived = $archived
        $response.Restarted = $restarted
        $response.SizeBefore = $sizeBefore
        $response.SizeAfter = $sizeAfter
        $response.Gained = $sizeBefore - $sizeAfter
        return $response
    }

    # =========================================================================
    # LE LOOK
    # =========================================================================

    # Les polices choisissables : celles que l'appli livre (les assets) et
    # celles que la machine a, fusionnées — le même dessin que la fenêtre
    # (WpfService.GetFontChoices) : une seule liste pour les deux UI.
    [string[]] GetFonts() {
        $names = @()
        foreach ($name in @($this.Config.GetFontNames())) {
            if ($names -notcontains $name) { $names += $name }
        }
        foreach ($font in @($this.Terminal.GetTerminalFonts())) {
            if ($names -notcontains $font.Name) { $names += $font.Name }
        }
        return @($names)
    }

    # Les paires de la tuile — le dépôt lit la table de make-icon, le service
    # met en forme (des lignes WslIconPairDto).
    [WslIconPairDto[]] GetIconPairs() {
        $rows = @()
        foreach ($pair in @($this.Terminal.GetIconPairs())) {
            $dto = [WslIconPairDto]::new()
            $dto.Name = "$($pair.Name)"
            $dto.Top = "$($pair.Top)"
            $dto.Bottom = "$($pair.Bottom)"
            $dto.TextColor = "$($pair.TextColor)"
            $rows += $dto
        }
        return @($rows)
    }

    # Ce que l'instance porte : son thème — la police et les couleurs que
    # Windows montre maintenant, le dessin de l'icône tel que l'instance l'a
    # noté — et la présence de notre fragment.
    [GetAppearanceResponseDto] GetAppearance([string]$instanceName) {
        $theme = $this.Terminal.GetAppearance($instanceName)

        $storedTheme = $this.Instances.GetInstance($instanceName).GetTheme()
        if ($null -ne $storedTheme) {
            $drawing = $storedTheme.GetIcon()
            if ($drawing.Text) { $theme.SetIcon($drawing) }
        }
        if ($this.Instances.HasIcon($instanceName)) {
            $theme.SetIconPath($this.Instances.GetIconPath($instanceName))
        }

        return $this.Map.ToAppearanceResponse($theme, $this.Terminal.HasFragment($instanceName))
    }

    # Les changements du look, un à la fois ou ensemble : le thème lu, la part
    # changée, le profil réécrit, le fichier de l'instance avec. Le dessin se
    # donne en quatre champs et se redessine ; une image prend le siège de
    # l'icône — le dessin reste derrière. Rend les changements faits, nus.
    [SetAppearanceResponseDto] SetAppearance([SetAppearanceDto]$dto) {
        $name = $dto.InstanceName
        $model = $this.Instances.GetInstance($name)

        # Le look vivant, le dessin de la recette posé dessus — un changement
        # de police ou de couleurs ne mange jamais la tuile.
        $theme = $this.Terminal.GetAppearance($name)
        $storedTheme = $model.GetTheme()
        if ($null -ne $storedTheme) {
            $drawing = $storedTheme.GetIcon()
            if ($drawing.Text) { $theme.SetIcon($drawing) }
        }

        $changes = @()
        $rewriteProfile = $false

        if ($dto.Font) {
            $theme.SetFont($dto.Font)
            $changes += "font '$($dto.Font)'"
            $rewriteProfile = $true
        }
        if ($dto.ColourScheme) {
            $theme.SetColourScheme($dto.ColourScheme)
            $changes += "colours '$($dto.ColourScheme)'"
            $rewriteProfile = $true
        }
        if ($dto.Icon) {
            $iconPath = $this.Instances.GetIconPath($name)
            $theme.SetIcon($this.Terminal.DrawIcon($name, $iconPath, $dto.Icon))
            $theme.SetIconPath($iconPath)
            $changes += "icon"
            $rewriteProfile = $true
        }
        if ($dto.IconImage) {
            # Le fichier remplace l'image au siège ; le dessin derrière ne
            # bouge pas, et le profil ne change pas — il pointe le siège.
            $this.Instances.SaveIcon($name, $dto.IconImage)
            $theme.SetIconPath($this.Instances.GetIconPath($name))
            $changes += "icon image"
        }

        if (-not $rewriteProfile) {
            $response = [SetAppearanceResponseDto]::new()
            $response.InstanceName = $name
            $response.Changes = @($changes)
            return $response
        }

        $guid = $this.Terminal.GetProfileGuid($name)
        if (-not $guid) {
            throw "Windows Terminal has no profile for '$name' - the look cannot be applied."
        }
        $this.Terminal.SaveFragment($name, $guid, $theme)
        $model.SetTheme($theme)
        $this.Instances.SaveInstance($model, "")
        $this.Terminal.TouchSettings()

        $response = [SetAppearanceResponseDto]::new()
        $response.InstanceName = $name
        $response.Changes = @($changes)
        return $response
    }

    # Les jeux de couleurs que Windows Terminal a : ceux qu'il livre, ceux que
    # l'utilisateur a ajoutés, et les noms que nos fragments portent — chacun
    # en ligne plate, triés par nom. La console peint ses aperçus avec le fond
    # et le texte, la fenêtre sa grille avec les seize — une seule lecture.
    [WslColorSchemeDto[]] GetColorSchemes() {
        $rows = @()
        foreach ($scheme in @($this.Terminal.GetColorSchemes())) {
            $dto = [WslColorSchemeDto]::new()
            foreach ($property in $scheme.PSObject.Properties) {
                $dto.$($property.Name) = $property.Value
            }
            $rows += $dto
        }
        return @($rows)
    }

    # =========================================================================
    # LES PACKS
    # =========================================================================

    # Ce que la fenêtre des packs montre : les portés, les offrables (la
    # famille de l'instance, le catalogue, ce qui manque), les retirables.
    [GetPacksResponseDto] GetPacks([string]$instanceName) {
        $catalog = $this.ReadCatalog()
        $packsDirectory = $this.PacksDirectory($instanceName)
        $installed = @($this.Wsl.GetInstalledPacks($instanceName, $packsDirectory))
        $family = $this.Wsl.GetFamily($instanceName)

        $response = [GetPacksResponseDto]::new()
        $response.Installed = @($installed)

        $candidate = @()
        foreach ($pack in @($catalog.OfferedFor($family))) {
            if ($installed -contains $pack.GetName()) { continue }
            $candidate += $this.Map.ToPackDto($pack)
        }
        $response.Candidate = @($candidate)

        # Les retirables à la main : les visibles ; un invisible part avec le
        # dernier qui le requiert.
        $removable = @()
        foreach ($packName in $installed) {
            $pack = $catalog.GetPack($packName)
            if ($null -ne $pack -and -not $pack.GetOffered()) { continue }
            $removable += $packName
        }
        $response.Removable = @($removable)

        return $response
    }

    # L'installation d'un pack et de ses requirements : résolus ici, les
    # installés sautés et dits, le reste derrière la porte sudo transitoire.
    # Le déroulé s'arrête au premier pas qui échoue.
    [AddPackResponseDto] AddPack([AddPackDto]$dto) {
        $name = $dto.InstanceName
        $catalog = $this.ReadCatalog()
        $packsDirectory = $this.PacksDirectory($name)
        $installed = @($this.Wsl.GetInstalledPacks($name, $packsDirectory))
        $errorLog = Join-Path $this.Instances.GetFolder($name) "pack-errors.log"

        $toInstall = @($catalog.ResolveSelection(@($dto.PackName), $installed))
        $skipped = @()
        foreach ($resolved in @($catalog.ResolveSelection(@($dto.PackName), @()))) {
            if ($installed -contains $resolved) { $skipped += $resolved }
        }

        $response = [AddPackResponseDto]::new()
        $response.InstanceName = $name
        $response.ExitCode = 0
        $response.Installed = @()
        $response.Skipped = @($skipped)

        if ($toInstall.Count -eq 0) {
            $response.Outcome = "already"
            return $response
        }

        $done = @()
        $outcome = "installed"
        $failCode = 0
        foreach ($packName in $toInstall) {
            $pack = $catalog.GetPack($packName)
            # Un requirement que ce checkout ne porte pas est sauté ; le pack
            # qui l'a demandé est celui qui échouera.
            if ($null -eq $pack) { continue }

            $result = $this.InstallPack($name, $pack, $packsDirectory, $errorLog)
            if ($result.Step -eq "declined") { $outcome = "declined"; break }
            if ($result.Step -eq "copy") { $outcome = "copy-failed"; $failCode = $result.ExitCode; break }
            if ($result.Step -ne "installed") { $outcome = "failed"; $failCode = $result.ExitCode; break }
            $done += $result.Pack
        }

        $response.Outcome = $outcome
        $response.ExitCode = $failCode
        $response.Installed = @($done)
        return $response
    }

    # Le départ d'un pack — ce qui part avec lui résolu par le catalogue, un
    # pack encore requis refusant tout le retrait avant que rien ne bouge.
    [RemovePackResponseDto] RemovePack([RemovePackDto]$dto) {
        $name = $dto.InstanceName
        $catalog = $this.ReadCatalog()
        $packsDirectory = $this.PacksDirectory($name)
        $installed = @($this.Wsl.GetInstalledPacks($name, $packsDirectory))
        $errorLog = Join-Path $this.Instances.GetFolder($name) "pack-errors.log"

        $toRemove = @($catalog.ResolveRemoval($installed, @($dto.PackName), @()))

        $response = [RemovePackResponseDto]::new()
        $response.InstanceName = $name
        $response.ExitCode = 0
        $response.Dependents = @()

        $conflicts = @($catalog.GetRemovalConflicts($installed, $toRemove, @()))
        if ($conflicts.Count -gt 0) {
            $response.Outcome = "conflict"
            $response.Dependents = @($catalog.GetBlockers($dto.PackName, $installed, $toRemove, @()))
            return $response
        }

        foreach ($packName in $toRemove) {
            $result = $this.RemoveOne($name, $packName, $packsDirectory, $errorLog)
            if ($null -ne $result) {
                $response.Outcome = if ($result.Step -eq "remove") { "self-failed" } else { "folder-failed" }
                $response.ExitCode = $result.ExitCode
                return $response
            }
        }

        # Les dépendances que les retraits ont laissées, reprises une fois —
        # là où plus rien ne peut les tenir.
        $null = $this.Wsl.RunOrphanCleanup($name)

        $response.Outcome = "removed"
        return $response
    }

    # Le choix entier de la fenêtre : ce qui entre, ce qui sort. Le premier
    # échec arrête la course ; ce qui est déjà fait reste. Le rapport est lu
    # des deux listages — ce qui a vraiment bougé, pas ce qui fut demandé.
    [ManagePacksResponseDto] ManagePacks([ManagePacksDto]$dto) {
        $name = $dto.InstanceName
        $catalog = $this.ReadCatalog()
        $packsDirectory = $this.PacksDirectory($name)
        $errorLog = Join-Path $this.Instances.GetFolder($name) "pack-errors.log"
        Remove-Item -Path $errorLog -Force -ErrorAction SilentlyContinue

        $before = @($this.Wsl.GetInstalledPacks($name, $packsDirectory))

        # Ce qui part avec les retraits, résolu ici — la question ne montre
        # que des noms — et le garde du choix entier : un pack encore requis
        # par un porté qui reste fait refuser tout le lot avant que rien ne
        # bouge.
        $toRemove = @($catalog.ResolveRemoval($before, @($dto.ToRemove), @($dto.ToAdd)))
        $conflicts = @($catalog.GetRemovalConflicts($before, $toRemove, @($dto.ToAdd)))
        if ($conflicts.Count -gt 0) {
            throw ("'{0}' cannot be removed: required by {1}." -f $conflicts[0].Name, ($conflicts[0].Blockers -join " and "))
        }

        $response = [ManagePacksResponseDto]::new()
        $response.InstanceName = $name
        $response.ExitCode = 0
        $response.Installed = @()
        $response.Removed = @()
        $response.Failed = @()

        foreach ($packName in @($dto.ToAdd)) {
            $pack = $catalog.GetPack($packName)
            if ($null -eq $pack) { continue }
            $result = $this.InstallPack($name, $pack, $packsDirectory, $errorLog)
            # Un pack qui décline n'est pas un échec : sa question a reçu non,
            # il n'entre pas, et la course continue.
            if ($result.Step -in @("installed", "declined")) { continue }

            $response.Outcome = "failed"
            $response.ExitCode = $result.ExitCode
            $response.Failed = @($result.Pack)
            $after = @($this.Wsl.GetInstalledPacks($name, $packsDirectory))
            $response.Installed = @($this.DiffNames($after, $before))
            return $response
        }

        foreach ($packName in $toRemove) {
            $result = $this.RemoveOne($name, $packName, $packsDirectory, $errorLog)
            if ($null -eq $result) { continue }

            $response.Outcome = "failed"
            $response.ExitCode = $result.ExitCode
            $response.Failed = @($result.Pack)
            $after = @($this.Wsl.GetInstalledPacks($name, $packsDirectory))
            $response.Installed = @($this.DiffNames($after, $before))
            $response.Removed = @($this.DiffNames($before, $after))
            return $response
        }

        if ($toRemove.Count -gt 0) {
            $null = $this.Wsl.RunOrphanCleanup($name)
        }

        $after = @($this.Wsl.GetInstalledPacks($name, $packsDirectory))
        $response.Outcome = "ok"
        $response.Installed = @($this.DiffNames($after, $before))
        $response.Removed = @($this.DiffNames($before, $after))
        return $response
    }

    # =========================================================================
    # LE MONDE DOCKER
    # =========================================================================

    # Le magasin : les images gardées de la maison. La route image de la
    # naissance s'en sert pour offrir ce qui est déjà là — leur ligne porte la
    # même mise en forme que les sources : le nom, sa date entre parenthèses.
    [WslDockerImageDto[]] GetAllSavedImages() {
        $rows = @()
        foreach ($image in @($this.Docker.GetAllSavedImages())) {
            $dto = [WslDockerImageDto]::new()
            $dto.Name = "$($image.Name) ($($image.Modified.ToString("dd'/'MM HH:mm")))"
            $dto.Path = "$($image.Path)"
            $dto.Uploaded = ((Split-Path -Path (Split-Path -Path "$($image.Path)" -Parent) -Leaf) -match '-[0-9a-f]{8}$')
            $rows += $dto
        }
        return @($rows)
    }

    # La porte : une référence qui ne nomme aucun hôte (alpine:latest) est à
    # Docker Hub, et se demande par son API — le premier curl du PATH ; une
    # qui nomme son hôte ou porte un digest passe par docker manifest. Le
    # pourquoi rendu avec le non est la phrase de la porte elle-même : la
    # saisie se vérifie par elle.
    [IsRegistryImageValidResponseDto] IsRegistryImageValid([string]$imageRef) {
        $answer = $this.Docker.TestRegistryImage($imageRef)
        $dto = [IsRegistryImageValidResponseDto]::new()
        $dto.Valid = [bool]$answer.Ok
        $dto.Why = "$($answer.Why)"
        return $dto
    }

    # =========================================================================
    # L'ARCHIVE
    # =========================================================================

    # L'export : la place vérifiée ici et refusée si elle manque, l'arrêt sous
    # le permis (une archive lit un disque immobile), le tar écrit — une
    # archive interrompue ne reste pas, elle ressemblerait à une sauvegarde —
    # le look copié à côté, et l'instance remise en route si l'arrêt fut nôtre.
    # Le nom de l'archive ne se demande pas : XX devient XX_archive, écrasée si
    # elle existe déjà.
    [ArchiveResponseDto] Archive([ArchiveDto]$dto) {
        $name = $dto.InstanceName
        $format = $dto.Format
        $archiveName = "$($name)_archive"
        $archiveDir = $this.Archives.GetFolder($archiveName)
        $archiveTar = Join-Path $archiveDir "$archiveName.$format"

        # La place, avant que quoi que ce soit écrive.
        $diskBytes = $this.Instances.GetVhdxSize($name)
        $freeBytes = $this.Instances.GetFreeSpace($archiveDir)
        if ($freeBytes -lt $diskBytes) {
            $drive = (Split-Path -Qualifier ([System.IO.Path]::GetFullPath($archiveDir))).TrimEnd(':')
            throw ("Not enough room on {0}: needed {1}, free {2}." -f $drive, (Format-Size $diskBytes), (Format-Size $freeBytes))
        }

        $stopped = $false
        if (@($this.Wsl.GetRunningNames()) -contains $name) {
            if (-not $dto.Permit) {
                throw "'$name' is running, and stopping it was not allowed: an archive reads a still disk."
            }
            $this.Wsl.Terminate($name)
            $stopped = $true
        }

        $stored = $this.Instances.GetInstance($name)
        $theme = $stored.GetTheme()
        if ($null -eq $theme) { $theme = [WslTheme]::Default($name) }

        try {
            # L'écrasement : l'archive du même nom part d'abord.
            if ($this.Archives.HasArchive($archiveName)) {
                $this.Archives.DeleteArchive($archiveName)
            }
            $this.Archives.EnsureFolder($archiveName)

            try {
                $this.Wsl.Export($name, $archiveTar, $format)
            } catch {
                # Une archive partielle restée sur le disque ressemblerait à
                # une sauvegarde, plus tard.
                Remove-Item $archiveTar -Force -ErrorAction SilentlyContinue
                throw
            }

            # Le look à côté du tar — le même fichier qu'une instance, plus la
            # réponse de Docker Desktop, que l'originale ne pourra plus dire.
            if ($this.Instances.HasIcon($name)) {
                $this.Archives.SaveIcon($archiveName, $this.Instances.GetIconPath($name))
                $theme.SetIconPath($this.Archives.GetIconPath($archiveName))
            }

            $archive = [WslInstance]::new()
            $archive.SetName($archiveName)
            $archive.SetIsArchive($true)
            $archive.SetDefaultUser($stored.GetDefaultUser())
            $archive.SetTheme($theme)
            $this.Archives.SaveInstance($archive, $this.Docker.GetDesktopState($name))
        } finally {
            # Trouvée en route, remise en route — quoi que l'export ait fait.
            if ($stopped) { $this.Wsl.Start($name) }
        }

        $response = [ArchiveResponseDto]::new()
        $response.InstanceName = $name
        $response.ArchiveDir = $archiveDir
        $response.Tar = $archiveTar
        $response.LookFont = $theme.GetFontName()
        $response.LookColourScheme = $theme.GetColorScheme()
        $response.Docker = $this.Docker.GetDesktopState($name)
        $response.Stopped = $stopped
        return $response
    }

    # L'archive rebâtie : le nom proposé sans le suffixe — refusé si une
    # instance du même nom est inscrite, ou si un dossier l'attend déjà —
    # l'import, le marqueur aussitôt, le look depuis le fichier à côté du tar,
    # l'icône, le profil. Docker Desktop : l'instance y entre comme l'archive
    # le dit, sans question.
    [RestoreResponseDto] Restore([RestoreDto]$dto) {
        $archiveName = $dto.ArchiveName
        $name = $dto.InstanceName

        foreach ($distro in @($this.Wsl.GetAllDistros())) {
            if ($distro.GetName() -eq $name) { throw "An instance named '$name' already exists." }
        }
        $installPath = $this.Instances.GetFolder($name)
        if (Test-Path $installPath) {
            throw "A folder with that name already exists: $installPath"
        }

        $tar = $this.Archives.GetTar($archiveName)
        if (-not $tar) {
            throw "No tar in the archive folder: $($this.Archives.GetFolder($archiveName))"
        }

        $this.Wsl.Import($name, $installPath, $tar)
        $this.Instances.WriteMarker($name, "restore")

        $stored = $this.Archives.GetInstance($archiveName)
        $theme = $stored.GetTheme()
        if ($null -eq $theme) { $theme = [WslTheme]::Default($name) }
        if ($this.Archives.HasIcon($archiveName)) {
            $this.Instances.SaveIcon($name, $this.Archives.GetIconPath($archiveName))
            $theme.SetIconPath($this.Instances.GetIconPath($name))
        }

        $guid = $this.Terminal.GetProfileGuid($name)
        if ($guid) { $this.Terminal.SaveFragment($name, $guid, $theme) }

        $instance = [WslInstance]::new()
        $instance.SetName($name)
        $instance.SetDefaultUser($stored.GetDefaultUser())
        $instance.SetTheme($theme)
        $this.Instances.SaveInstance($instance, "")
        $this.Terminal.TouchSettings()

        # L'archive disait que Docker Desktop connaissait son originale : la
        # nouvelle y entre. Sans question — le fait vient d'elle.
        $carried = $this.Archives.GetDocker($archiveName)
        if ($carried -eq "yes" -and $this.Docker.GetDesktopState($name) -eq "no") {
            $this.Docker.SetDesktopState($name)
            $null = $this.Docker.RestartDesktop()
        }

        $response = [RestoreResponseDto]::new()
        $response.ArchiveName = $archiveName
        $response.InstanceName = $name
        return $response
    }

    # Le dossier de l'archive, entier — le tar, le look, la réponse avec.
    [DeleteArchiveResponseDto] DeleteArchive([string]$archive) {
        $this.Archives.DeleteArchive($archive)
        $response = [DeleteArchiveResponseDto]::new()
        $response.ArchiveName = $archive
        return $response
    }

    # La copie : la place vérifiée ici et refusée si elle manque (le pic —
    # deux fois le disque), le look et la réponse de Docker capturés avant
    # l'arrêt, l'export déballé dans le nouveau dossier, le look posé sur la
    # copie — et Docker Desktop comme l'originale, sans question. L'originale
    # s'arrête pour une lecture immobile, et repart quand l'arrêt fut nôtre.
    [DuplicateResponseDto] Duplicate([DuplicateDto]$dto) {
        $source = $dto.SourceName
        $copy = $dto.CopyName

        foreach ($distro in @($this.Wsl.GetAllDistros())) {
            if ($distro.GetName() -eq $copy) { throw "An instance named '$copy' already exists." }
        }
        foreach ($archive in @($this.Archives.GetAllArchives())) {
            if ($archive.GetName() -eq $copy) { throw "An instance named '$copy' already exists." }
        }

        # La place, avant tout : la copie lit l'instance en tar et le déplie
        # en même temps — le pic est deux fois le disque.
        $destination = $this.Instances.GetFolder($copy)
        $diskBytes = $this.Instances.GetVhdxSize($source)
        $needed = 2 * $diskBytes
        $freeBytes = $this.Instances.GetFreeSpace($destination)
        if ($freeBytes -lt $needed) {
            $drive = (Split-Path -Qualifier ([System.IO.Path]::GetFullPath($destination))).TrimEnd(':')
            throw ("Not enough room on {0}: needed {1}, free {2}." -f $drive, (Format-Size $needed), (Format-Size $freeBytes))
        }

        # Ce que Windows montre maintenant, capturé avant l'arrêt — la copie
        # doit tout porter.
        $stored = $this.Instances.GetInstance($source)
        $theme = $this.Terminal.GetAppearance($source)
        $storedTheme = $stored.GetTheme()
        if ($null -ne $storedTheme) {
            $drawing = $storedTheme.GetIcon()
            if ($drawing.Text) { $theme.SetIcon($drawing) }
        }
        $dockerCarried = $this.Docker.GetDesktopState($source)

        $stopped = $false
        if (@($this.Wsl.GetRunningNames()) -contains $source) {
            $this.Wsl.Terminate($source)
            $stopped = $true
        }

        $tempTar = Join-Path (Split-Path $destination -Parent) "$copy-export.tar.gz"
        try {
            $this.Wsl.Export($source, $tempTar, "tar.gz")
            $this.Wsl.Import($copy, $destination, $tempTar)

            # À nous à partir d'ici, quoi qu'il arrive ensuite.
            $this.Instances.WriteMarker($copy, "duplicate")

            if ($this.Instances.HasIcon($source)) {
                $this.Instances.SaveIcon($copy, $this.Instances.GetIconPath($source))
                $theme.SetIconPath($this.Instances.GetIconPath($copy))
            }
            $guid = $this.Terminal.GetProfileGuid($copy)
            if ($guid) { $this.Terminal.SaveFragment($copy, $guid, $theme) }

            $instance = [WslInstance]::new()
            $instance.SetName($copy)
            $instance.SetDefaultUser($stored.GetDefaultUser())
            $instance.SetTheme($theme)
            $this.Instances.SaveInstance($instance, "")
            $this.Terminal.TouchSettings()

            # Docker Desktop comme l'originale, sans question.
            if ($dockerCarried -eq "yes" -and $this.Docker.GetDesktopState($copy) -eq "no") {
                $this.Docker.SetDesktopState($copy)
                $null = $this.Docker.RestartDesktop()
            }
        } finally {
            # L'image temporaire s'en va dans tous les cas — elle vaut deux
            # fois le disque — et la source, trouvée en route, repart.
            if (Test-Path $tempTar) { Remove-Item $tempTar -Force -ErrorAction SilentlyContinue }
            if ($stopped) { $this.Wsl.Start($source) }
        }

        $response = [DuplicateResponseDto]::new()
        $response.SourceName = $source
        $response.CopyName = $copy
        return $response
    }

    # =========================================================================
    # LES PAS PARTAGÉS
    # =========================================================================

    # Le Dto de l'archivage pour un nom : le format que l'archivage d'abord
    # prend, et le permis — la porte a déjà demandé.
    hidden [ArchiveDto] ArchiveDtoFor([string]$name) {
        $dto = [ArchiveDto]::new()
        $dto.InstanceName = $name
        $dto.Format = "tar.gz"
        $dto.Permit = $true
        return $dto
    }

    # Le look posé sur une instance neuve : la police assurée (le dépôt en
    # livre une, le téléchargement est le repli), l'icône dessinée depuis le
    # nom, le fragment écrit sous le guid que WSL a donné, le fichier de
    # l'instance avec — et la touche, pour que Terminal relise. Rend les
    # nouvelles qui méritent une ligne ; le dessin est une décoration : son
    # échec laisse une ligne, pas un fichier.
    hidden [string[]] ApplyLook([string]$name, [WslInstance]$instance) {
        $warnings = @()
        $theme = $instance.GetTheme()

        if (-not $this.Terminal.IsFontInstalled($theme.GetFontName())) {
            try { $this.Terminal.InstallFont($theme.GetFontName(), "") }
            catch { $warnings += "the font '$($theme.GetFontName())' would not install: $($_.Exception.Message)" }
        }

        $iconPath = $this.Instances.GetIconPath($name)
        $iconDrawn = $false
        try {
            $theme.SetIcon($this.Terminal.DrawIcon($name, $iconPath, $null))
            $iconDrawn = $true
        } catch {
            Remove-Item $iconPath -Force -ErrorAction SilentlyContinue
            $warnings += "no icon ($($_.Exception.Message))"
        }

        # Les guids que Terminal peut encore atteindre, et le ménage : chaque
        # reconstruction orpheline le profil d'avant dans le settings.json de
        # l'utilisateur — les entrées de ce nom sans fragment vivant s'en
        # vont, nos fragments pointant un guid mort aussi. Une seule passe :
        # la naissance n'attend pas après un profil qui n'arrive pas.
        $fragments = $this.Terminal.GetWslGuids($name)
        if (@($fragments.Guids).Count -gt 0) {
            $ghosts = $this.Terminal.PruneGhostEntries($name, @($fragments.Guids))
            foreach ($path in @($ghosts.Unreadable)) {
                $warnings += "ghost entries NOT pruned in $path (unreadable JSON - a // comment breaks ConvertFrom-Json; remove them by hand)"
            }
        }
        $null = $this.Terminal.RemoveStaleFragments(@($fragments.Guids))

        if ($fragments.Guid) {
            # Pas d'icône dessinée, pas de ligne d'icône : Terminal montre la
            # sienne.
            $theme.SetIconPath($(if ($iconDrawn) { $iconPath } else { "" }))
            $this.Terminal.SaveFragment($name, $fragments.Guid, $theme)
        } else {
            $warnings += "no WSL fragment for '$name' - the profile was not applied"
        }

        $instance.SetTheme($theme)
        $this.Instances.SaveInstance($instance, "")
        $this.Terminal.TouchSettings()

        return @($warnings)
    }

    # L'inscription chez Docker Desktop, le pas qu'une naissance doit : le nom
    # écrit (le fichier de Docker le prend ou la naissance jette), l'appli
    # redémarrée pour injecter son client.
    hidden [void] RegisterDockerDesktop([string]$name) {
        try { $this.Docker.SetDesktopState($name) }
        catch { throw "Docker Desktop's settings could not take '$name': $($_.Exception.Message)" }
        if (-not $this.Docker.RestartDesktop()) {
            throw "Docker Desktop would not restart to pick '$name' up."
        }
    }

    # Le client de Docker injecté — Docker Desktop s'injecte à son rythme :
    # quelques demandes, puis le verdict, qui est une ligne de la réponse, pas
    # un échec.
    hidden [string[]] WaitDockerClient([string]$name) {
        $usable = $false
        for ($attempt = 1; $attempt -le 5 -and -not $usable; $attempt++) {
            $usable = $this.Wsl.TestInInstance($name, @("docker", "version"))
            if (-not $usable) { Start-Sleep -Seconds 2 }
        }
        if ($usable) {
            return @("Docker Desktop: ready - 'docker' works in this instance.")
        }
        return @(
            "Docker Desktop: 'docker' does not answer in this instance yet.",
            "run 'docker version' in there; if it names the socket's permissions, restart Docker Desktop and open a new terminal."
        )
    }

    # Les packs choisis à la naissance : résolus (les requirements d'abord),
    # installés au mieux — l'échec est une note, jamais une naissance ratée.
    hidden [string[]] InstallChosenPacks([string]$name, [string[]]$chosen) {
        $catalog = $this.ReadCatalog()
        $packsDirectory = $this.PacksDirectory($name)
        $errorLog = Join-Path $this.Instances.GetFolder($name) "pack-errors.log"

        foreach ($packName in @($catalog.ResolveSelection($chosen, @()))) {
            $pack = $catalog.GetPack($packName)
            if ($null -eq $pack) { continue }

            $result = $this.InstallPack($name, $pack, $packsDirectory, $errorLog)
            if ($result.Step -in @("installed", "declined")) { continue }

            $notes = @("'$($result.Pack)' installation failed.")
            $now = @($this.Wsl.GetInstalledPacks($name, $packsDirectory))
            $skipped = @()
            foreach ($wanted in $chosen) {
                if ($wanted -ne $result.Pack -and $now -notcontains $wanted) { $skipped += $wanted }
            }
            if ($skipped.Count -gt 0) { $notes += "$($skipped -join ', ') installation skipped." }
            return $notes
        }
        return @()
    }

    # Le catalogue du checkout, relu — les dossiers à pack.conf, en
    # déclarations, pour les règles du modèle (qui requiert qui).
    hidden [WslPackCatalog] ReadCatalog() {
        $catalog = [WslPackCatalog]::new()
        $catalog.SetPacks(@($this.Packs.GetAllPacks()))
        return $catalog
    }

    # Où vivent les packs de l'instance : son home, demandé — ~ ne s'étend que
    # dans un shell — puis le dossier. Une instance qui ne sait pas dire son
    # home le dit ici, au moment où ça compte.
    hidden [string] PacksDirectory([string]$name) {
        $home = $this.Wsl.GetHome($name)
        if (-not $home) { throw "'$name' did not say where its user's home is." }
        return "$home/.config/packs"
    }

    # L'installation d'un pack et ses trois pas : son dossier posé d'abord,
    # sa moitié root ensuite — avant que la porte ne s'ouvre : le pack de
    # shell porte sudo lui-même, et sur un Debian nu sa moitié root tourne là
    # où aucune porte ne peut encore s'ouvrir — puis son install derrière la
    # porte, retirée après. Un pack qui décline (code 2) n'est pas un échec :
    # son dossier ressort, et le pas le dit. Rend {Pack ; Step ; ExitCode} —
    # Step : installed, declined, copy, root, install.
    hidden [object] InstallPack([string]$name, [WslPack]$pack, [string]$packsDirectory, [string]$errorLog) {
        $target = "$packsDirectory/$($pack.GetName())"

        # Le dossier d'abord : un remove.sh lancé plus tard dans le même geste
        # demande quel pack installé revendique un paquet, et celui-ci doit en
        # être.
        $code = $this.Wsl.CopyFolderIntoInstance($name, $this.Packs.GetFolder($pack.GetName()), $target)
        if ($code -ne 0) {
            # Un dossier à moitié posé passerait pour une installation : il
            # ressort, comme les autres échecs.
            $null = $this.Wsl.RemoveFolderInInstance($name, $target)
            return [PSCustomObject]@{ Pack = $pack.GetName(); Step = "copy"; ExitCode = $code }
        }

        if ($this.Wsl.HasInInstance($name, "$target/install_root.sh")) {
            $rootCode = $this.Wsl.RunScriptInInstance($name, $target, "install_root.sh", $true, $errorLog)
            if ($rootCode -ne 0) {
                # Rien de ce pack n'a encore tourné son install : son dossier
                # ressort. Ce que sa moitié root a posé reste — la relancer
                # reprend là.
                $null = $this.Wsl.RemoveFolderInInstance($name, $target)
                return [PSCustomObject]@{ Pack = $pack.GetName(); Step = "root"; ExitCode = $rootCode }
            }
        }

        $sudoWindow = $false
        try {
            $sudoWindow = $this.Wsl.OpenPackSudoWindow($name)
            $code = $this.Wsl.RunScriptInInstance($name, $target, "install.sh", $false, $errorLog)
        } finally {
            if ($sudoWindow) { $this.Wsl.ClosePackSudoWindow($name) }
        }

        # Code 2 : le pack a posé une question, la réponse était non — il
        # n'entre pas, son dossier ressort, et rien n'a échoué.
        if ($code -eq 2) {
            $null = $this.Wsl.RemoveFolderInInstance($name, $target)
            return [PSCustomObject]@{ Pack = $pack.GetName(); Step = "declined"; ExitCode = 0 }
        }
        # Un pack à moitié installé vaut moins que rien : son dossier ressort,
        # et ce que son install avait déjà écrit reste.
        if ($code -ne 0) {
            $null = $this.Wsl.RemoveFolderInInstance($name, $target)
            return [PSCustomObject]@{ Pack = $pack.GetName(); Step = "install"; ExitCode = $code }
        }

        return [PSCustomObject]@{ Pack = $pack.GetName(); Step = "installed"; ExitCode = 0 }
    }

    # Un pack sorti : son remove.sh — en root, le geste des retraits — puis
    # son dossier. Un pack sans remove.sh a été installé avant que les packs
    # n'en aient un : son dossier part, rien n'est défait, et aucune ligne ne
    # le dit. Rend $null quand c'est fait, le pas et le code sinon.
    hidden [object] RemoveOne([string]$name, [string]$packName, [string]$packsDirectory, [string]$errorLog) {
        $target = "$packsDirectory/$packName"

        # Le remove.sh du CATALOGUE quand il est là : la copie de l'instance
        # est un instantané de son install, et un retrait que le script
        # d'hier bloque n'a pas de sortie (vécu : un remove.sh qui visait
        # les paquets de l'image). Un pack retiré du catalogue garde sa
        # copie, telle quelle.
        $catalogRemove = Join-Path $this.Packs.GetFolder($packName) "remove.sh"
        if (Test-Path $catalogRemove) {
            $null = $this.Wsl.CopyFileIntoInstance($name, $catalogRemove, "$target/remove.sh")
        }

        if ($this.Wsl.HasInInstance($name, "$target/remove.sh")) {
            $code = $this.Wsl.RunScriptInInstance($name, $target, "remove.sh", $true, $errorLog)
            if ($code -ne 0) {
                return [PSCustomObject]@{ Pack = $packName; Step = "remove"; ExitCode = $code }
            }
        }

        $code = $this.Wsl.RemoveFolderInInstance($name, $target)
        if ($code -ne 0) {
            return [PSCustomObject]@{ Pack = $packName; Step = "folder"; ExitCode = $code }
        }
        return $null
    }

    # Ce qui est dans $after et pas dans $before — les rapports des packs se
    # lisent des deux listages, jamais de ce qui fut demandé.
    hidden [string[]] DiffNames([string[]]$after, [string[]]$before) {
        $diff = @()
        foreach ($name in $after) {
            if ($before -notcontains $name) { $diff += $name }
        }
        return @($diff)
    }
}
