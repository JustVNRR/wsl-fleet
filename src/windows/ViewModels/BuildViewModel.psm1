# ==============================================================================
# LA NAISSANCE — LE VIEWMODEL
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout lui-même ce qu'il
# tire.
# Le formulaire de la naissance : le nom et le compte vérifiés en direct (la
# ligne rouge sous la boîte, CREATE qui suit), la route — Dockerfile, image,
# registre — chacune avec sa liste, son téléversement, son téléchargement et
# sa corbeille (les recettes du dépôt ne se suppriment pas : la corbeille ne
# touche qu'aux téléversées), l'onboarding, et les deux cases. CREATE vérifie,
# lit la famille de la source choisie, ouvre la fenêtre des packs PAR-DESSUS,
# puis pose son BuildDto et crie Done — la vue se ferme là-dessus.
#
# Il a le service en main : il lit ses listes lui-même, téléverse, retire et
# vérifie le registre — les portes liées de l'ancien monde n'ont plus lieu
# d'être. Les sélecteurs de fichiers sont chez la vue (graphisme), qui
# rappelle ici avec le chemin choisi.
using module .\BaseViewModel.psm1
using module ..\Dto\InstanceDto.psm1

class BuildViewModel : BaseViewModel {
    hidden [object]$_instance
    hidden [string]$_views = ""

    hidden [string]$_name = ""
    hidden [string]$_nameError = ""
    hidden [bool]$_nameOk = $false
    hidden [string]$_user = ""
    hidden [string]$_userError = ""
    hidden [bool]$_userOk = $false

    hidden [int]$_roadIndex = 0
    hidden [object[]]$_dockerfiles = @()
    hidden [int]$_dockerfileIndex = -1
    hidden [object[]]$_onboardings = @()
    hidden [int]$_onboardingIndex = -1
    hidden [object[]]$_images = @()
    hidden [int]$_imageIndex = -1

    hidden [string]$_registryRef = ""
    hidden [string]$_imageError = ""
    hidden [string]$_registryError = ""
    hidden [bool]$_saveImage = $false
    hidden [bool]$_registerDocker = $true
    hidden [bool]$_runFirstBoot = $true

    # Le Dto de la naissance, posé par CREATE — la vue le lit en se fermant.
    [object]$Result = $null

    [System.Windows.Input.ICommand]$CreateCommand

    BuildViewModel([object]$instanceService, [string]$viewsRoot) {
        $this._instance = $instanceService
        $this._views = $viewsRoot

        try {
            $sources = $this._instance.GetBuildSources()
            $this._dockerfiles = @($sources.Dockerfiles)
            $this._onboardings = @($sources.Onboardings)
            $this._images = @($this._instance.GetAllSavedImages())
        } catch { }
        if ($this._dockerfiles.Count -gt 0) { $this._dockerfileIndex = 0 }
        if ($this._onboardings.Count -gt 0) { $this._onboardingIndex = 0 }
        if ($this._images.Count -gt 0) { $this._imageIndex = 0 }

        # Le compte proposé : le nom Windows, nettoyé — la même règle qu'au
        # cli.
        $proposal = "$env:USERNAME".ToLower()
        $proposal = $proposal.Normalize([Text.NormalizationForm]::FormD) -replace '\p{Mn}', ''
        $proposal = $proposal -replace '[^a-z0-9_-]+', '-'
        $proposal = $proposal.Trim('-', '_')
        if (-not ($proposal -cmatch '^[a-z][a-z0-9_-]*$')) { $proposal = "" }
        $this._user = $proposal

        $this.AddProperty("Name", { return $this._name }, {
            param($value)
            if ($this._name -ne "$value") { $this._name = "$value"; $this.OnPropertyChanged("Name"); $this.ValidateName() }
        })
        $this.AddProperty("NameError", { return $this._nameError }, {
            param($value)
            if ($this._nameError -ne "$value") { $this._nameError = "$value"; $this.OnPropertyChanged("NameError") }
        })
        $this.AddProperty("NameOk", { return $this._nameOk }, { param($value) })
        $this.AddProperty("User", { return $this._user }, {
            param($value)
            if ($this._user -ne "$value") { $this._user = "$value"; $this.OnPropertyChanged("User"); $this.ValidateUser() }
        })
        $this.AddProperty("UserError", { return $this._userError }, {
            param($value)
            if ($this._userError -ne "$value") { $this._userError = "$value"; $this.OnPropertyChanged("UserError") }
        })
        $this.AddProperty("UserOk", { return $this._userOk }, { param($value) })

        $this.AddProperty("RoadIndex", { return $this._roadIndex }, {
            param($value)
            if ($this._roadIndex -ne [int]$value) { $this._roadIndex = [int]$value; $this.OnPropertyChanged("RoadIndex"); $this.RoadMoved() }
        })
        $this.AddProperty("ShowDockerfile", { return ($this._roadIndex -eq 0) }, { param($value) })
        $this.AddProperty("ShowImage", { return ($this._roadIndex -eq 1) }, { param($value) })
        $this.AddProperty("ShowRegistry", { return ($this._roadIndex -eq 2) }, { param($value) })

        $this.AddProperty("Dockerfiles", { return $this._dockerfiles }, {
            param($value)
            $this._dockerfiles = @($value)
            $this.OnPropertyChanged("Dockerfiles")
            $this.OnPropertyChanged("CanTrashDockerfile")
            $this.OnPropertyChanged("CanDownloadDockerfile")
        })
        $this.AddProperty("DockerfileIndex", { return $this._dockerfileIndex }, {
            param($value)
            if ($this._dockerfileIndex -ne [int]$value) {
                $this._dockerfileIndex = [int]$value
                $this.OnPropertyChanged("DockerfileIndex")
                $this.OnPropertyChanged("CanTrashDockerfile")
                $this.OnPropertyChanged("CanDownloadDockerfile")
            }
        })
        $this.AddProperty("Onboardings", { return $this._onboardings }, {
            param($value)
            $this._onboardings = @($value)
            $this.OnPropertyChanged("Onboardings")
            $this.OnPropertyChanged("CanTrashOnboarding")
            $this.OnPropertyChanged("CanDownloadOnboarding")
        })
        $this.AddProperty("OnboardingIndex", { return $this._onboardingIndex }, {
            param($value)
            if ($this._onboardingIndex -ne [int]$value) {
                $this._onboardingIndex = [int]$value
                $this.OnPropertyChanged("OnboardingIndex")
                $this.OnPropertyChanged("CanTrashOnboarding")
                $this.OnPropertyChanged("CanDownloadOnboarding")
            }
        })
        $this.AddProperty("DockerImages", { return $this._images }, {
            param($value)
            $this._images = @($value)
            $this.OnPropertyChanged("DockerImages")
            $this.OnPropertyChanged("CanTrashImage")
            $this.OnPropertyChanged("CanDownloadImage")
        })
        $this.AddProperty("ImageIndex", { return $this._imageIndex }, {
            param($value)
            if ($this._imageIndex -ne [int]$value) {
                $this._imageIndex = [int]$value
                $this.OnPropertyChanged("ImageIndex")
                $this.OnPropertyChanged("CanTrashImage")
                $this.OnPropertyChanged("CanDownloadImage")
            }
        })
        # Les mains des lignes : la corbeille ne vit que sur une téléversée,
        # le téléchargement sur n'importe quelle ligne choisie.
        $this.AddProperty("CanTrashDockerfile", { return $this.RowUploaded($this._dockerfiles, $this._dockerfileIndex) }, { param($value) })
        $this.AddProperty("CanTrashOnboarding", { return $this.RowUploaded($this._onboardings, $this._onboardingIndex) }, { param($value) })
        $this.AddProperty("CanTrashImage", { return $this.RowUploaded($this._images, $this._imageIndex) }, { param($value) })
        $this.AddProperty("CanDownloadDockerfile", { return ($this._dockerfileIndex -ge 0) }, { param($value) })
        $this.AddProperty("CanDownloadOnboarding", { return ($this._onboardingIndex -ge 0) }, { param($value) })
        $this.AddProperty("CanDownloadImage", { return ($this._imageIndex -ge 0) }, { param($value) })

        $this.AddProperty("RegistryRef", { return $this._registryRef }, {
            param($value)
            if ($this._registryRef -ne "$value") { $this._registryRef = "$value"; $this.OnPropertyChanged("RegistryRef") }
        })
        $this.AddProperty("ImageError", { return $this._imageError }, {
            param($value)
            if ($this._imageError -ne "$value") { $this._imageError = "$value"; $this.OnPropertyChanged("ImageError") }
        })
        $this.AddProperty("RegistryError", { return $this._registryError }, {
            param($value)
            if ($this._registryError -ne "$value") { $this._registryError = "$value"; $this.OnPropertyChanged("RegistryError") }
        })

        $this.AddProperty("SaveImage", { return $this._saveImage }, {
            param($value)
            if ($this._saveImage -ne [bool]$value) { $this._saveImage = [bool]$value; $this.OnPropertyChanged("SaveImage") }
        })
        $this.AddProperty("RegisterDocker", { return $this._registerDocker }, {
            param($value)
            if ($this._registerDocker -ne [bool]$value) { $this._registerDocker = [bool]$value; $this.OnPropertyChanged("RegisterDocker") }
        })
        $this.AddProperty("RunFirstBoot", { return $this._runFirstBoot }, {
            param($value)
            if ($this._runFirstBoot -ne [bool]$value) { $this._runFirstBoot = [bool]$value; $this.OnPropertyChanged("RunFirstBoot") }
        })

        # Le droit se lit par une MÉTHODE : un bloc ne voit pas les
        # propriétés de la coquille sur l'objet nu (mesuré).
        $this.CreateCommand = $this.NewCommand(
            { param($vm) $vm.Create() },
            { param($vm) $vm.CanCreate() })

        $this.ValidateName()
        $this.ValidateUser()
    }

    # La ligne choisie d'une liste — la vue la lit pour sa porte rouge et son
    # nom proposé.
    [object] SelectedRow([string]$listName) {
        $rows = switch ($listName) { "Dockerfiles" { $this._dockerfiles } "Onboardings" { $this._onboardings } default { $this._images } }
        $at = switch ($listName) { "Dockerfiles" { $this._dockerfileIndex } "Onboardings" { $this._onboardingIndex } default { $this._imageIndex } }
        if ($at -lt 0 -or $at -ge $rows.Count) { return $null }
        return $rows[$at]
    }

    [void] RemoveSelected([string]$listName) {
        $at = switch ($listName) { "Dockerfiles" { $this._dockerfileIndex } "Onboardings" { $this._onboardingIndex } default { $this._imageIndex } }
        $this.RemoveRecipe($listName, $at)
    }

    # CREATE suit les deux verdicts — le droit de la commande, lu par elle.
    [bool] CanCreate() {
        return ($this._nameOk -and $this._userOk)
    }

    hidden [bool] RowUploaded([object[]]$rows, [int]$at) {
        if ($at -lt 0 -or $at -ge $rows.Count) { return $false }
        return [bool]$rows[$at].Uploaded
    }

    # Le nom : forme, pris — la ligne rouge et le droit de CREATE.
    [void] ValidateName() {
        $problem = ""
        if (-not $this._name) { $problem = "Give a name." }
        elseif ($this._name -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*$') { $problem = "Letters, digits, '.', '_' and '-' only." }
        else {
            try {
                $taken = @($this._instance.GetAll() | Where-Object { -not $_.IsArchive } | ForEach-Object { $_.Name })
                if ($taken -contains $this._name) { $problem = "An instance named '$($this._name)' already exists." }
            } catch { }
        }
        $this._nameError = $problem
        $this._nameOk = (-not $problem)
        $this.OnPropertyChanged("NameError")
        $this.OnPropertyChanged("NameOk")
        $this.CreateCommand.RaiseCanExecuteChanged()
    }

    # Le compte : la forme, quand l'onboarding tourne.
    [void] ValidateUser() {
        $problem = ""
        if ("$($this._user)" -cnotmatch '^[a-z][a-z0-9_-]*$') { $problem = "Lowercase letters, digits, '_' and '-' only, starting with a letter." }
        $this._userError = $problem
        $this._userOk = (-not $problem)
        $this.OnPropertyChanged("UserError")
        $this.OnPropertyChanged("UserOk")
        $this.CreateCommand.RaiseCanExecuteChanged()
    }

    # La route : l'onboarding suit — une image (téléversée ou du registre)
    # est présumée complète, un Dockerfile garde la case.
    [void] RoadMoved() {
        $this._runFirstBoot = -not ($this._roadIndex -eq 1 -or $this._roadIndex -eq 2)
        $this.OnPropertyChanged("RunFirstBoot")
        $this.OnPropertyChanged("ShowDockerfile")
        $this.OnPropertyChanged("ShowImage")
        $this.OnPropertyChanged("ShowRegistry")
    }

    # --- les téléversements, les retraits, les sorties -----------------------

    [void] AddDockerfile([string]$source) {
        $this.AddRecipe("dockerfiles", $source, "Dockerfile", "Dockerfiles")
    }

    [void] AddOnboarding([string]$source) {
        $this.AddRecipe("onboardings", $source, "onboarding.sh", "Onboardings")
    }

    [void] AddImage([string]$source) {
        $this.AddRecipe("dockerimages", $source, [IO.Path]::GetFileName($source), "DockerImages")
    }

    hidden [void] AddRecipe([string]$kind, [string]$source, [string]$fileName, [string]$listName) {
        if (-not $source) { return }
        $up = [UploadRecipeDto]::new()
        $up.Kind = $kind
        $up.Source = $source
        $up.FileName = $fileName
        try {
            $row = @($this._instance.UploadRecipe($up))[0]
        } catch { return }
        switch ($listName) {
            "Dockerfiles" {
                $this._dockerfiles = @($this._dockerfiles) + @($row)
                $this._dockerfileIndex = $this._dockerfiles.Count - 1
            }
            "Onboardings" {
                $this._onboardings = @($this._onboardings) + @($row)
                $this._onboardingIndex = $this._onboardings.Count - 1
            }
            "DockerImages" {
                $this._images = @($this._images) + @($row)
                $this._imageIndex = $this._images.Count - 1
            }
        }
        $this.OnPropertyChanged($listName)
        $this.OnPropertyChanged("DockerfileIndex")
        $this.OnPropertyChanged("OnboardingIndex")
        $this.OnPropertyChanged("ImageIndex")
        $this.OnPropertyChanged("CanTrashDockerfile")
        $this.OnPropertyChanged("CanTrashOnboarding")
        $this.OnPropertyChanged("CanTrashImage")
        $this.OnPropertyChanged("CanDownloadDockerfile")
        $this.OnPropertyChanged("CanDownloadOnboarding")
        $this.OnPropertyChanged("CanDownloadImage")
    }

    [void] DeleteDockerfile() {
        $this.RemoveRecipe("Dockerfiles", $this._dockerfileIndex)
    }

    [void] DeleteOnboarding() {
        $this.RemoveRecipe("Onboardings", $this._onboardingIndex)
    }

    [void] DeleteImage() {
        $this.RemoveRecipe("DockerImages", $this._imageIndex)
    }

    hidden [void] RemoveRecipe([string]$listName, [int]$at) {
        $rows = switch ($listName) { "Dockerfiles" { $this._dockerfiles } "Onboardings" { $this._onboardings } default { $this._images } }
        if ($at -lt 0 -or $at -ge $rows.Count) { return }
        $row = $rows[$at]
        if (-not $row.Uploaded) { return }
        try { $this._instance.DeleteRecipe("$($row.Path)") } catch { return }
        $kept = @($rows | Where-Object { "$($_.Path)" -ne "$($row.Path)" })
        switch ($listName) {
            "Dockerfiles" { $this._dockerfiles = $kept; $this._dockerfileIndex = if ($kept.Count -gt 0) { 0 } else { -1 } }
            "Onboardings" { $this._onboardings = $kept; $this._onboardingIndex = if ($kept.Count -gt 0) { 0 } else { -1 } }
            "DockerImages" { $this._images = $kept; $this._imageIndex = if ($kept.Count -gt 0) { 0 } else { -1 } }
        }
        $this.OnPropertyChanged($listName)
        $this.OnPropertyChanged("DockerfileIndex")
        $this.OnPropertyChanged("OnboardingIndex")
        $this.OnPropertyChanged("ImageIndex")
        $this.OnPropertyChanged("CanTrashDockerfile")
        $this.OnPropertyChanged("CanTrashOnboarding")
        $this.OnPropertyChanged("CanTrashImage")
    }

    # Le nom proposé au téléchargement : celui du téléversement, l'empreinte
    # au nom de l'emplacement retirée. La vue ouvre son sélecteur dessus.
    [string] DownloadName([string]$listName) {
        $rows = switch ($listName) { "Dockerfiles" { $this._dockerfiles } "Onboardings" { $this._onboardings } default { $this._images } }
        $at = switch ($listName) { "Dockerfiles" { $this._dockerfileIndex } "Onboardings" { $this._onboardingIndex } default { $this._imageIndex } }
        if ($at -lt 0 -or $at -ge $rows.Count) { return "" }
        $row = $rows[$at]
        $base = (Split-Path -Path (Split-Path -Path "$($row.Path)" -Parent) -Leaf) -replace '-[0-9a-f]{8}$', ''
        return "$base$([IO.Path]::GetExtension("$($row.Path)"))"
    }

    [void] ExportRecipeTo([string]$listName, [string]$target) {
        if (-not $target) { return }
        $rows = switch ($listName) { "Dockerfiles" { $this._dockerfiles } "Onboardings" { $this._onboardings } default { $this._images } }
        $at = switch ($listName) { "Dockerfiles" { $this._dockerfileIndex } "Onboardings" { $this._onboardingIndex } default { $this._imageIndex } }
        if ($at -lt 0 -or $at -ge $rows.Count) { return }
        try {
            $exp = [ExportRecipeDto]::new()
            $exp.Path = "$($rows[$at].Path)"
            $exp.Target = $target
            $this._instance.ExportRecipe($exp)
        } catch { }
    }

    # --- CREATE ---------------------------------------------------------------

    # CREATE : la vérification entière, la famille, la fenêtre des packs
    # PAR-DESSUS (Cancel y revient, le formulaire intact), puis le Dto et le
    # cri Done.
    [void] Create() {
        $this.ValidateName()
        if ($this._runFirstBoot) { $this.ValidateUser() } else { $this._userOk = $true }
        $this.OnPropertyChanged("UserOk")

        $this._imageError = if ($this._roadIndex -eq 1 -and $this._imageIndex -lt 0) { "Upload a Docker image first." } else { "" }
        $this.OnPropertyChanged("ImageError")

        # Le registre est demandé — pas de pull — et un nom inconnu se refuse
        # ici, sur la ligne rouge, pas à la naissance.
        $this._registryError = ""
        if ($this._roadIndex -eq 2) {
            $ref = "$($this._registryRef)".Trim()
            if (-not $ref) {
                $this._registryError = "Name the image first, e.g. alpine:latest."
            } else {
                try {
                    $verdict = @($this._instance.IsRegistryImageValid($ref))[0]
                    if (-not $verdict.Valid) { $this._registryError = "Unknown registry image '$ref' - $($verdict.Why)" }
                } catch { }
            }
        }
        $this.OnPropertyChanged("RegistryError")

        if (-not $this._nameOk -or -not $this._userOk -or $this._imageError -or $this._registryError) { return }

        # La famille : lue sur la ligne choisie (le FROM est déjà lu) —
        # la fenêtre des packs s'ouvre par-dessus, le formulaire figé
        # derrière ; Cancel y revient, intact.
        $family = ""
        if ($this._roadIndex -eq 0 -and $this._dockerfileIndex -ge 0) { $family = "$($this._dockerfiles[$this._dockerfileIndex].Family)" }
        $packs = @()
        try { $packs = @($this._instance.GetBuildPacks()) } catch { }
        $pickedPacks = [BaseViewModel]::OpenFace($this._views, "BuildPacks", @("$($this._name)".Trim(), $family, $packs))
        if ($null -eq $pickedPacks) { return }

        $dto = [BuildDto]::new()
        $dto.Name = "$($this._name)".Trim()
        $dto.User = if ($this._runFirstBoot) { "$($this._user)".Trim() } else { "" }
        if ($this._roadIndex -eq 2) {
            $dto.BuildType = [WslBuildType]::Registry
            $dto.BuildPath = "$($this._registryRef)".Trim()
        } elseif ($this._roadIndex -eq 1) {
            $dto.BuildType = [WslBuildType]::Image
            $dto.BuildPath = "$($this._images[$this._imageIndex].Path)"
        } else {
            $dto.BuildType = [WslBuildType]::Dockerfile
            $dto.BuildPath = "$($this._dockerfiles[$this._dockerfileIndex].Path)"
            $dto.Context = Split-Path -Parent $dto.BuildPath
        }
        $dto.Onboarding = if ($this._runFirstBoot -and $this._onboardings.Count -gt 0) { "$($this._onboardings[$this._onboardingIndex].Path)" } else { "" }
        $dto.Packs = @($pickedPacks)
        $dto.KeepImage = $this._saveImage
        $dto.RegisterDocker = $this._registerDocker
        $this.Result = $dto
        $this.OnPropertyChanged("Done")
    }
}
