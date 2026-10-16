# ==============================================================================
# BUILD — LA VUE WPF
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewWpf.psm1
using module ..\..\..\ViewModels\BuildViewModel.psm1

# La naissance, la fenêtre : le DataContext est le BuildViewModel — l'état
# et les commandes se bindent en XAML. Ce fichier ne garde que ce que WPF
# demande : le chargement, le focus d'ouverture, l'Entrée mangée après un
# sélecteur (mesuré), les sélecteurs de fichiers (graphisme — le ViewModel
# reçoit le chemin), la confirmation des corbeilles, la porte de fermeture —
# et il rend le Dto du ViewModel.
class WpfBuildView : BaseViewWpf {
    # L'Entrée mangée après un sélecteur de fichier (mesuré).
    hidden [bool]$EatEnter = $false
    hidden [object]$Vm = $null

    [object] Ask([object]$instanceService) {
        $self = $this
        $this.Vm = [BuildViewModel]::new($instanceService)

        # La porte d'ouverture : la vue dit où et comment on trouve une boîte
        # (son propre dossier), le ViewModel ne dit que « ouvre la boîte X ».
        $viewsRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $this.Vm.Ouverture = {
            param($gesture, $arguments)
            return $self.Vm.FindFace($viewsRoot, $gesture, $arguments)
        }

        $this.Title = "Add instance"
        $this.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
        $this.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $this.ResizeMode = [System.Windows.ResizeMode]::NoResize
        $this.Load((Join-Path $PSScriptRoot "Build.xaml"))
        $this.WearDefault()
        $this.Dress($null, 15)
        $this.DataContext = $this.Vm

        $this.Add_ContentRendered({ $null = $this.Find("TxtName").Focus() })

        # La porte de fermeture — METHODE 1 : le ViewModel dit « j'ai fini »,
        # la vue ferme.
        $this.Vm.DemandeFermeture = { param($result) $self.Result = $result; $self.Close() }

        # L'Entrée mangée après chaque sélecteur : à sa fermeture, l'Entrée
        # retombe sur le bouton par défaut — CREATE a déjà fermé la fenêtre
        # une fois ailleurs (mesuré).
        $this.Add_PreviewKeyDown({
            param($source, $e)
            if ($self.EatEnter -and $e.Key -eq [System.Windows.Input.Key]::Enter) { $e.Handled = $true }
        })
        $this.Add_PreviewKeyUp({
            param($source, $e)
            if ($self.EatEnter -and $e.Key -eq [System.Windows.Input.Key]::Enter) {
                $self.EatEnter = $false
                $e.Handled = $true
            }
        })

        # Téléverser : le fichier choisi, le ViewModel le pose — la ligne
        # rendue rejoint sa liste.
        $this.Find("BtnDockerfileUpload").Add_Click({
            $dialog = New-Object Microsoft.Win32.OpenFileDialog
            $dialog.Title = "A Dockerfile for the build"
            $dialog.Filter = "Dockerfiles (Dockerfile*)|Dockerfile*|All files (*.*)|*.*"
            $picked = $dialog.ShowDialog($self)
            $self.EatEnter = $true
            if ($picked -ne $true) { return }
            $self.Vm.AddDockerfile($dialog.FileName)
        })
        $this.Find("BtnOnboardingUpload").Add_Click({
            $dialog = New-Object Microsoft.Win32.OpenFileDialog
            $dialog.Title = "An onboarding script for the build"
            $dialog.Filter = "Shell scripts (*.sh)|*.sh|All files (*.*)|*.*"
            $picked = $dialog.ShowDialog($self)
            $self.EatEnter = $true
            if ($picked -ne $true) { return }
            $self.Vm.AddOnboarding($dialog.FileName)
        })
        $this.Find("BtnDockerImageUpload").Add_Click({
            $dialog = New-Object Microsoft.Win32.OpenFileDialog
            $dialog.Title = "A Docker image for the build"
            $dialog.Filter = "Docker images (*.tar)|*.tar|All files (*.*)|*.*"
            $picked = $dialog.ShowDialog($self)
            $self.EatEnter = $true
            if ($picked -ne $true) { return }
            $self.Vm.AddImage($dialog.FileName)
        })

        # Télécharger : le nom proposé par le ViewModel (celui du
        # téléversement), où l'utilisateur pointe.
        $this.Find("BtnDockerfileDownload").Add_Click({ $self.SaveOut("Dockerfiles") })
        $this.Find("BtnOnboardingDownload").Add_Click({ $self.SaveOut("Onboardings") })
        $this.Find("BtnDockerImageDownload").Add_Click({ $self.SaveOut("DockerImages") })

        # The edit buttons: the selected file, opened in the code editor.
        $this.Find("BtnDockerfileEdit").Add_Click({ $self.Vm.EditSource("Dockerfiles") })
        $this.Find("BtnOnboardingEdit").Add_Click({ $self.Vm.EditSource("Onboardings") })

        # La corbeille : la porte rouge d'abord (le graphisme demande), le
        # ViewModel retire ensuite, la liste suit.
        $this.Find("BtnDockerfileDelete").Add_Click({ $self.Trash("Dockerfiles", "Delete Dockerfile", "Dockerfiles") })
        $this.Find("BtnOnboardingDelete").Add_Click({ $self.Trash("Onboardings", "Delete onboarding shell", "onboarding shells") })
        $this.Find("BtnDockerImageDelete").Add_Click({ $self.Trash("DockerImages", "Delete Docker image", "Docker images") })

        # The recipe: the + opens the name popup, the editor opens the folder,
        # the trash goes through the same red door.
        $this.Find("BtnRecipeNew").Add_Click({ $self.Vm.NewRecipe() })
        $this.Find("BtnRecipeEdit").Add_Click({ $self.Vm.EditSource("Recipes") })
        $this.Find("BtnRecipeDelete").Add_Click({ $self.Trash("Recipes", "Delete recipe", "recipes") })

        # Les saisies : les liens sont à sens unique — WPF lit ; les
        # écritures passent par ici, relayées aux méthodes du ViewModel qui
        # gardent, valident et réveillent leurs portes.
        $this.Find("TxtName").Add_TextChanged({ param($source, $e) $self.Vm.SetName("$($source.Text)") })
        $this.Find("TxtUser").Add_TextChanged({ param($source, $e) $self.Vm.SetUser("$($source.Text)") })
        $this.Find("TxtRegistry").Add_TextChanged({ param($source, $e) $self.Vm.SetRegistryRef("$($source.Text)") })
        $this.Find("CmbRoad").Add_SelectionChanged({ param($source, $e) if ([int]$source.SelectedIndex -ge 0) { $self.Vm.SetRoad([int]$source.SelectedIndex) } })
        $this.Find("CmbDockerfile").Add_SelectionChanged({ param($source, $e) if ([int]$source.SelectedIndex -ge 0) { $self.Vm.SetDockerfileIndex([int]$source.SelectedIndex) } })
        $this.Find("CmbOnboarding").Add_SelectionChanged({ param($source, $e) if ([int]$source.SelectedIndex -ge 0) { $self.Vm.SetOnboardingIndex([int]$source.SelectedIndex) } })
        $this.Find("CmbDockerImage").Add_SelectionChanged({ param($source, $e) if ([int]$source.SelectedIndex -ge 0) { $self.Vm.SetImageIndex([int]$source.SelectedIndex) } })
        $this.Find("CmbRecipe").Add_SelectionChanged({ param($source, $e) if ([int]$source.SelectedIndex -ge 0) { $self.Vm.SetRecipeIndex([int]$source.SelectedIndex) } })
        $this.Find("ChkSaveImage").Add_Checked({ param($source, $e) $self.Vm.SetSaveImage([bool]$source.IsChecked) })
        $this.Find("ChkSaveImage").Add_Unchecked({ param($source, $e) $self.Vm.SetSaveImage([bool]$source.IsChecked) })
        $this.Find("ChkSaveImageRecipe").Add_Checked({ param($source, $e) $self.Vm.SetSaveImage([bool]$source.IsChecked) })
        $this.Find("ChkSaveImageRecipe").Add_Unchecked({ param($source, $e) $self.Vm.SetSaveImage([bool]$source.IsChecked) })
        $this.Find("ChkRegisterDocker").Add_Checked({ param($source, $e) $self.Vm.SetRegisterDocker([bool]$source.IsChecked) })
        $this.Find("ChkRegisterDocker").Add_Unchecked({ param($source, $e) $self.Vm.SetRegisterDocker([bool]$source.IsChecked) })
        $this.Find("ChkRunOnboarding").Add_Checked({ param($source, $e) $self.Vm.SetRunOnboarding([bool]$source.IsChecked) })
        $this.Find("ChkRunOnboarding").Add_Unchecked({ param($source, $e) $self.Vm.SetRunOnboarding([bool]$source.IsChecked) })

        $this.Find("BtnAddCancel").Add_Click({ $self.Close() })

        $this.FitToContent($null)
        $null = $this.OpenAs($null)
        return $this.Result
    }

    # Le téléchargement d'une ligne : le nom proposé, le sélecteur, et le
    # ViewModel sort la ligne choisie où l'utilisateur a pointé.
    hidden [void] SaveOut([string]$listName) {
        $proposed = $this.Vm.DownloadName($listName)
        if (-not $proposed) { return }
        $save = New-Object Microsoft.Win32.SaveFileDialog
        $save.Title = "Save '$proposed'"
        $save.FileName = $proposed
        $save.Filter = "All files (*.*)|*.*"
        $picked = $save.ShowDialog($this)
        $this.EatEnter = $true
        if ($picked -ne $true) { return }
        $this.Vm.ExportRecipeTo($listName, $save.FileName)
    }

    # La corbeille d'une ligne : la porte rouge d'abord — une recette du
    # dépôt n'a pas de corbeille, le ViewModel le sait aussi.
    hidden [void] Trash([string]$listName, [string]$title, [string]$what) {
        $row = $this.Vm.SelectedRow($listName)
        if (-not $row) { return }
        if (-not $row.Uploaded) { return }
        if (-not $this.ConfirmAs($this, $title, "Remove '$($row.Name)'?", "")) { return }
        $this.Vm.RemoveSelected($listName)
    }
}
