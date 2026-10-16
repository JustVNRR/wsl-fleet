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
# puis pose son BuildDto et demande la fermeture — la vue se ferme là-dessus.
#
# Il a le service en main : il lit ses listes lui-même, téléverse, retire et
# vérifie le registre — les portes liées de l'ancien monde n'ont plus lieu
# d'être. Les sélecteurs de fichiers sont chez la vue (graphisme), qui
# rappelle ici avec le chemin choisi.
using module .\BaseViewModel.psm1
using module ..\Dtos\InstanceDto.psm1

class BuildViewModel : BaseViewModel {
    hidden [object]$_instance

    # L'état bindable : de VRAIES propriétés de classe — WPF ne lit que
    # celles-là. Les verdicts (cachés) nourrissent le droit de CREATE.
    [string]$Name = ""
    [string]$NameError = ""
    [string]$User = ""
    [string]$UserError = ""

    [int]$RoadIndex = 0
    # Les listes montrent leurs NOMS, en chaînes (WPF les affiche sûrement —
    # mesuré : un DisplayMemberPath sur nos objets reste muet), les lignes
    # gardent le reste.
    [object[]]$Dockerfiles = @()
    [string[]]$DockerfileNames = @()
    [int]$DockerfileIndex = -1
    [object[]]$Onboardings = @()
    [string[]]$OnboardingNames = @()
    [int]$OnboardingIndex = -1
    [object[]]$DockerImages = @()
    [string[]]$ImageNames = @()
    [int]$ImageIndex = -1
    [object[]]$Recipes = @()
    [string[]]$RecipeNames = @()
    [int]$RecipeIndex = -1
    [bool]$ShowDockerfile = $true
    [bool]$ShowImage = $false
    [bool]$ShowRegistry = $false
    [bool]$ShowRecipe = $false
    [bool]$CanTrashDockerfile = $false
    [bool]$CanTrashOnboarding = $false
    [bool]$CanTrashImage = $false
    [bool]$CanTrashRecipe = $false
    [bool]$CanDownloadDockerfile = $false
    [bool]$CanDownloadOnboarding = $false
    [bool]$CanDownloadImage = $false

    [string]$RegistryRef = ""
    [string]$ImageError = ""
    [string]$RegistryError = ""
    [string]$RecipeError = ""
    [bool]$SaveImage = $false
    [bool]$RegisterDocker = $true
    [bool]$RunOnboarding = $true

    hidden [bool]$_nameOk = $false
    hidden [bool]$_userOk = $false

    # Le Dto de la naissance, posé par CREATE — la vue le lit en se fermant.
    [object]$Result = $null

    [System.Windows.Input.ICommand]$CreateCommand

    BuildViewModel([object]$instanceService) {
        $this._instance = $instanceService

        try {
            $sources = $this._instance.GetBuildSources()
            $this.Dockerfiles = @($sources.Dockerfiles)
            $this.Onboardings = @($sources.Onboardings)
            $this.DockerImages = @($this._instance.GetAllSavedImages())
            $this.Recipes = @($sources.Recipes)
        } catch { }
        if ($this.Dockerfiles.Count -gt 0) { $this.DockerfileIndex = 0 }
        if ($this.Onboardings.Count -gt 0) { $this.OnboardingIndex = 0 }
        if ($this.DockerImages.Count -gt 0) { $this.ImageIndex = 0 }
        if ($this.Recipes.Count -gt 0) { $this.RecipeIndex = 0 }

        # Le compte proposé : le nom Windows, nettoyé — la même règle qu'au
        # cli.
        $proposal = "$env:USERNAME".ToLower()
        $proposal = $proposal.Normalize([Text.NormalizationForm]::FormD) -replace '\p{Mn}', ''
        $proposal = $proposal -replace '[^a-z0-9_-]+', '-'
        $proposal = $proposal.Trim('-', '_')
        if (-not ($proposal -cmatch '^[a-z][a-z0-9_-]*$')) { $proposal = "" }
        $this.User = $proposal

        # Le droit se lit par une MÉTHODE : un bloc ne voit pas les
        # propriétés de la coquille sur l'objet nu (mesuré).
        $this.CreateCommand = $this.NewCommand(
            { param($vm) $vm.Create() },
            { param($vm) $vm.CanCreate() })

        $this.ValidateName()
        $this.ValidateUser()
        $this.SyncLists()
    }

    # Les liens XAML sont à sens unique : la vue relaie chaque saisie ici —
    # garde, validation, effet sur la route et cri des mains vivent d'un
    # seul côté.
    [void] SetName([string]$value) {
        if ($this.Name -cne "$value") {
            $this.Name = "$value"
            $this.OnPropertyChanged("Name")
            $this.ValidateName()
        }
    }

    [void] SetUser([string]$value) {
        if ($this.User -cne "$value") {
            $this.User = "$value"
            $this.OnPropertyChanged("User")
            $this.ValidateUser()
        }
    }

    [void] SetRegistryRef([string]$value) {
        if ($this.RegistryRef -cne "$value") {
            $this.RegistryRef = "$value"
            $this.OnPropertyChanged("RegistryRef")
        }
    }

    [void] SetRoad([int]$value) {
        if ($this.RoadIndex -ne $value) {
            $this.RoadIndex = $value
            $this.OnPropertyChanged("RoadIndex")
            $this.RoadMoved()
        }
    }

    [void] SetDockerfileIndex([int]$value) {
        if ($this.DockerfileIndex -ne $value) {
            $this.DockerfileIndex = $value
            $this.OnPropertyChanged("DockerfileIndex")
            $this.SyncLists()
        }
    }

    [void] SetOnboardingIndex([int]$value) {
        if ($this.OnboardingIndex -ne $value) {
            $this.OnboardingIndex = $value
            $this.OnPropertyChanged("OnboardingIndex")
            $this.SyncLists()
        }
    }

    [void] SetImageIndex([int]$value) {
        if ($this.ImageIndex -ne $value) {
            $this.ImageIndex = $value
            $this.OnPropertyChanged("ImageIndex")
            $this.SyncLists()
        }
    }

    [void] SetRecipeIndex([int]$value) {
        if ($this.RecipeIndex -ne $value) {
            $this.RecipeIndex = $value
            $this.OnPropertyChanged("RecipeIndex")
            $this.SyncLists()
        }
    }

    [void] SetSaveImage([bool]$value) { $this.SaveImage = [bool]$value; $this.OnPropertyChanged("SaveImage") }
    [void] SetRegisterDocker([bool]$value) { $this.RegisterDocker = [bool]$value; $this.OnPropertyChanged("RegisterDocker") }
    [void] SetRunOnboarding([bool]$value) { $this.RunOnboarding = [bool]$value; $this.OnPropertyChanged("RunOnboarding") }

    # Les listes et leurs mains : les noms que les listes montrent (en
    # chaînes), la corbeille qui ne vit que sur une téléversée, le
    # téléchargement sur n'importe quelle ligne choisie.
    hidden [void] SyncLists() {
        $this.DockerfileNames = @($this.Dockerfiles | ForEach-Object { "$($_.Name)" })
        $this.OnboardingNames = @($this.Onboardings | ForEach-Object { "$($_.Name)" })
        $this.ImageNames = @($this.DockerImages | ForEach-Object { "$($_.Name)" })
        $this.RecipeNames = @($this.Recipes | ForEach-Object { "$($_.Name)" })
        $this.OnPropertyChanged("DockerfileNames")
        $this.OnPropertyChanged("OnboardingNames")
        $this.OnPropertyChanged("ImageNames")
        $this.OnPropertyChanged("RecipeNames")
        $this.CanTrashDockerfile = $this.RowUploaded($this.Dockerfiles, $this.DockerfileIndex)
        $this.CanTrashOnboarding = $this.RowUploaded($this.Onboardings, $this.OnboardingIndex)
        $this.CanTrashImage = $this.RowUploaded($this.DockerImages, $this.ImageIndex)
        $this.CanTrashRecipe = $this.RowUploaded($this.Recipes, $this.RecipeIndex)
        $this.CanDownloadDockerfile = ($this.DockerfileIndex -ge 0)
        $this.CanDownloadOnboarding = ($this.OnboardingIndex -ge 0)
        $this.CanDownloadImage = ($this.ImageIndex -ge 0)
        $this.OnPropertyChanged("CanTrashDockerfile")
        $this.OnPropertyChanged("CanTrashOnboarding")
        $this.OnPropertyChanged("CanTrashImage")
        $this.OnPropertyChanged("CanTrashRecipe")
        $this.OnPropertyChanged("CanDownloadDockerfile")
        $this.OnPropertyChanged("CanDownloadOnboarding")
        $this.OnPropertyChanged("CanDownloadImage")
    }

    # La ligne choisie d'une liste — la vue la lit pour sa porte rouge et son
    # nom proposé.
    [object] SelectedRow([string]$listName) {
        $rows = switch ($listName) { "Dockerfiles" { $this.Dockerfiles } "Onboardings" { $this.Onboardings } "Recipes" { $this.Recipes } default { $this.DockerImages } }
        $at = switch ($listName) { "Dockerfiles" { $this.DockerfileIndex } "Onboardings" { $this.OnboardingIndex } "Recipes" { $this.RecipeIndex } default { $this.ImageIndex } }
        if ($at -lt 0 -or $at -ge $rows.Count) { return $null }
        return $rows[$at]
    }

    [void] RemoveSelected([string]$listName) {
        $at = switch ($listName) { "Dockerfiles" { $this.DockerfileIndex } "Onboardings" { $this.OnboardingIndex } "Recipes" { $this.RecipeIndex } default { $this.ImageIndex } }
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
        if (-not $this.Name) { $problem = "Give a name." }
        elseif ($this.Name -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*$') { $problem = "Letters, digits, '.', '_' and '-' only." }
        else {
            try {
                $taken = @($this._instance.GetAll() | Where-Object { -not $_.IsArchive } | ForEach-Object { $_.Name })
                if ($taken -contains $this.Name) { $problem = "An instance named '$($this.Name)' already exists." }
            } catch { }
        }
        $this.NameError = $problem
        $this._nameOk = (-not $problem)
        $this.OnPropertyChanged("NameError")
        $this.OnPropertyChanged("NameOk")
        $this.CreateCommand.RaiseCanExecuteChanged()
    }

    # Le compte : la forme, quand l'onboarding tourne.
    [void] ValidateUser() {
        $problem = ""
        if ("$($this.User)" -cnotmatch '^[a-z][a-z0-9_-]*$') { $problem = "Lowercase letters, digits, '_' and '-' only, starting with a letter." }
        $this.UserError = $problem
        $this._userOk = (-not $problem)
        $this.OnPropertyChanged("UserError")
        $this.OnPropertyChanged("UserOk")
        $this.CreateCommand.RaiseCanExecuteChanged()
    }

    # La route : l'onboarding suit — une image (téléversée ou du registre)
    # est présumée complète, un Dockerfile garde la case.
    [void] RoadMoved() {
        $this.RunOnboarding = -not ($this.RoadIndex -eq 1 -or $this.RoadIndex -eq 2 -or $this.RoadIndex -eq 3)
        $this.ShowDockerfile = ($this.RoadIndex -eq 0)
        $this.ShowImage = ($this.RoadIndex -eq 1)
        $this.ShowRegistry = ($this.RoadIndex -eq 2)
        $this.ShowRecipe = ($this.RoadIndex -eq 3)
        $this.OnPropertyChanged("RunOnboarding")
        $this.OnPropertyChanged("ShowDockerfile")
        $this.OnPropertyChanged("ShowImage")
        $this.OnPropertyChanged("ShowRegistry")
        $this.OnPropertyChanged("ShowRecipe")
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
                $this.Dockerfiles = @($this.Dockerfiles) + @($row)
                $this.DockerfileIndex = $this.Dockerfiles.Count - 1
            }
            "Onboardings" {
                $this.Onboardings = @($this.Onboardings) + @($row)
                $this.OnboardingIndex = $this.Onboardings.Count - 1
            }
            "DockerImages" {
                $this.DockerImages = @($this.DockerImages) + @($row)
                $this.ImageIndex = $this.DockerImages.Count - 1
            }
        }
        $this.OnPropertyChanged($listName)
        $this.SyncLists()
        # The index is announced after the names: the combo resets its
        # selection as the names land, and this puts it back.
        $this.OnPropertyChanged("DockerfileIndex")
        $this.OnPropertyChanged("OnboardingIndex")
        $this.OnPropertyChanged("ImageIndex")
    }

    [void] DeleteDockerfile() {
        $this.RemoveRecipe("Dockerfiles", $this.DockerfileIndex)
    }

    [void] DeleteOnboarding() {
        $this.RemoveRecipe("Onboardings", $this.OnboardingIndex)
    }

    [void] DeleteImage() {
        $this.RemoveRecipe("DockerImages", $this.ImageIndex)
    }

    # A fresh recipe: the popup's name, the service makes the folder under it,
    # the list follows.
    [void] NewRecipe() {
        $chosen = $this.OpenBox("RecipeName", @())
        if (-not $chosen) { return }
        $request = [NewRecipeDto]::new()
        $request.Name = "$chosen"
        try { $row = @($this._instance.CreateRecipe($request))[0] } catch { return }
        $this.Recipes = @($this.Recipes) + @($row)
        $this.RecipeIndex = $this.Recipes.Count - 1
        $this.OnPropertyChanged("Recipes")
        $this.SyncLists()
        # The index is announced after the names: the combo resets its
        # selection as the names land, and this puts it back.
        $this.OnPropertyChanged("RecipeIndex")
    }

    # The selected row's path, opened in the code editor - any list that
    # offers the button, a repo's own row included.
    [void] EditSource([string]$listName) {
        $row = $this.SelectedRow($listName)
        if (-not $row) { return }
        try { $this._instance.OpenInEditor("$($row.Path)") } catch { }
    }

    [void] DeleteRecipe() {
        $this.RemoveRecipe("Recipes", $this.RecipeIndex)
    }

    hidden [void] RemoveRecipe([string]$listName, [int]$at) {
        $rows = switch ($listName) { "Dockerfiles" { $this.Dockerfiles } "Onboardings" { $this.Onboardings } "Recipes" { $this.Recipes } default { $this.DockerImages } }
        if ($at -lt 0 -or $at -ge $rows.Count) { return }
        $row = $rows[$at]
        if (-not $row.Uploaded) { return }
        try { $this._instance.DeleteRecipe("$($row.Path)") } catch { return }
        $kept = @($rows | Where-Object { "$($_.Path)" -ne "$($row.Path)" })
        switch ($listName) {
            "Dockerfiles" { $this.Dockerfiles = $kept; $this.DockerfileIndex = if ($kept.Count -gt 0) { 0 } else { -1 } }
            "Onboardings" { $this.Onboardings = $kept; $this.OnboardingIndex = if ($kept.Count -gt 0) { 0 } else { -1 } }
            "DockerImages" { $this.DockerImages = $kept; $this.ImageIndex = if ($kept.Count -gt 0) { 0 } else { -1 } }
            "Recipes" { $this.Recipes = $kept; $this.RecipeIndex = if ($kept.Count -gt 0) { 0 } else { -1 } }
        }
        $this.OnPropertyChanged($listName)
        $this.SyncLists()
        # The index is announced after the names: the combo resets its
        # selection as the names land, and this puts it back.
        $this.OnPropertyChanged("DockerfileIndex")
        $this.OnPropertyChanged("OnboardingIndex")
        $this.OnPropertyChanged("ImageIndex")
        $this.OnPropertyChanged("RecipeIndex")
    }

    # Le nom proposé au téléchargement : celui du téléversement, l'empreinte
    # au nom de l'emplacement retirée. La vue ouvre son sélecteur dessus.
    [string] DownloadName([string]$listName) {
        $rows = switch ($listName) { "Dockerfiles" { $this.Dockerfiles } "Onboardings" { $this.Onboardings } default { $this.DockerImages } }
        $at = switch ($listName) { "Dockerfiles" { $this.DockerfileIndex } "Onboardings" { $this.OnboardingIndex } default { $this.ImageIndex } }
        if ($at -lt 0 -or $at -ge $rows.Count) { return "" }
        $row = $rows[$at]
        $base = (Split-Path -Path (Split-Path -Path "$($row.Path)" -Parent) -Leaf) -replace '-[0-9a-f]{8}$', ''
        return "$base$([IO.Path]::GetExtension("$($row.Path)"))"
    }

    [void] ExportRecipeTo([string]$listName, [string]$target) {
        if (-not $target) { return }
        $rows = switch ($listName) { "Dockerfiles" { $this.Dockerfiles } "Onboardings" { $this.Onboardings } default { $this.DockerImages } }
        $at = switch ($listName) { "Dockerfiles" { $this.DockerfileIndex } "Onboardings" { $this.OnboardingIndex } default { $this.ImageIndex } }
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
    # la demande de fermeture.
    [void] Create() {
        $this.ValidateName()
        if ($this.RunOnboarding) { $this.ValidateUser() } else { $this._userOk = $true }
        $this.OnPropertyChanged("UserOk")

        $this.ImageError = if ($this.RoadIndex -eq 1 -and $this.ImageIndex -lt 0) { "Upload a Docker image first." } else { "" }
        $this.OnPropertyChanged("ImageError")

        $this.RecipeError = if ($this.RoadIndex -eq 3 -and $this.RecipeIndex -lt 0) { "Create a recipe first with the + button." } else { "" }
        $this.OnPropertyChanged("RecipeError")

        # Le registre est demandé — pas de pull — et un nom inconnu se refuse
        # ici, sur la ligne rouge, pas à la naissance.
        $this.RegistryError = ""
        if ($this.RoadIndex -eq 2) {
            $ref = "$($this.RegistryRef)".Trim()
            if (-not $ref) {
                $this.RegistryError = "Name the image first, e.g. alpine:latest."
            } else {
                try {
                    $verdict = @($this._instance.IsRegistryImageValid($ref))[0]
                    if (-not $verdict.Valid) { $this.RegistryError = "Unknown registry image '$ref' - $($verdict.Why)" }
                } catch { }
            }
        }
        $this.OnPropertyChanged("RegistryError")

        if (-not $this._nameOk -or -not $this._userOk -or $this.ImageError -or $this.RegistryError -or $this.RecipeError) { return }

        # La famille : lue sur la ligne choisie (le FROM est déjà lu) —
        # la fenêtre des packs s'ouvre par-dessus, le formulaire figé
        # derrière ; Cancel y revient, intact.
        $family = ""
        if ($this.RoadIndex -eq 0 -and $this.DockerfileIndex -ge 0) { $family = "$($this.Dockerfiles[$this.DockerfileIndex].Family)" }
        if ($this.RoadIndex -eq 3 -and $this.RecipeIndex -ge 0) { $family = "$($this.Recipes[$this.RecipeIndex].Family)" }
        $packs = @()
        try { $packs = @($this._instance.GetBuildPacks()) } catch { }
        $answer = $this.OpenBox("BuildPacks", @("$($this.Name)".Trim(), $family, $packs))
        if ($null -eq $answer) { return }
        $pickedPacks = @($answer.Packs)

        $dto = [BuildDto]::new()
        $dto.Name = "$($this.Name)".Trim()
        $dto.User = if ($this.RunOnboarding) { "$($this.User)".Trim() } else { "" }
        if ($this.RoadIndex -eq 2) {
            $dto.BuildType = [WslBuildType]::Registry
            $dto.BuildPath = "$($this.RegistryRef)".Trim()
        } elseif ($this.RoadIndex -eq 1) {
            $dto.BuildType = [WslBuildType]::Image
            $dto.BuildPath = "$($this.DockerImages[$this.ImageIndex].Path)"
        } elseif ($this.RoadIndex -eq 3) {
            $dto.BuildType = [WslBuildType]::Recipe
            $dto.Context = "$($this.Recipes[$this.RecipeIndex].Path)"
            $dto.BuildPath = Join-Path $dto.Context "Dockerfile"
        } else {
            $dto.BuildType = [WslBuildType]::Dockerfile
            $dto.BuildPath = "$($this.Dockerfiles[$this.DockerfileIndex].Path)"
            $dto.Context = Split-Path -Parent $dto.BuildPath
        }
        $dto.Onboarding = if ($this.RunOnboarding -and $this.Onboardings.Count -gt 0) { "$($this.Onboardings[$this.OnboardingIndex].Path)" } else { "" }
        $dto.Packs = @($pickedPacks)
        $dto.KeepImage = $this.SaveImage
        $dto.RegisterDocker = $this.RegisterDocker
        $this.Result = $dto
        $this.RequestClose()
    }
}
