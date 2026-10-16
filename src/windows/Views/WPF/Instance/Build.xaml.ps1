using module ..\BaseViewWpf.psm1
using module ..\..\..\ViewModels\BuildViewModel.psm1

class WpfBuildView : BaseViewWpf {

    hidden [bool]$EatEnter = $false
    hidden [object]$Vm = $null

    [object] Ask([object]$instanceService) {
        $self = $this
        $this.Vm = [BuildViewModel]::new($instanceService)

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

        $this.Vm.DemandeFermeture = { param($result) $self.Result = $result; $self.Close() }

        $this.Vm.add_PropertyChanged({
            param($source, $e)
            switch ("$($e.PropertyName)") {
                "NameError" { $self.ShowError("GuiNameError", "$($source.NameError)") }
                "UserError" { $self.ShowError("GuiUserError", "$($source.UserError)") }
                "ImageError" { $self.ShowError("GuiImageError", "$($source.ImageError)") }
                "RegistryError" { $self.ShowError("GuiRegistryError", "$($source.RegistryError)") }
                "RecipeError" { $self.ShowError("GuiRecipeError", "$($source.RecipeError)") }
            }
        })

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

        $this.Find("BtnDockerfileDownload").Add_Click({ $self.SaveOut("Dockerfiles") })
        $this.Find("BtnOnboardingDownload").Add_Click({ $self.SaveOut("Onboardings") })
        $this.Find("BtnDockerImageDownload").Add_Click({ $self.SaveOut("DockerImages") })

        $this.Find("BtnDockerfileEdit").Add_Click({ $self.Vm.EditSource("Dockerfiles") })
        $this.Find("BtnOnboardingEdit").Add_Click({ $self.Vm.EditSource("Onboardings") })

        $this.Find("BtnDockerfileDelete").Add_Click({ $self.Trash("Dockerfiles", "Delete Dockerfile", "Dockerfiles") })
        $this.Find("BtnOnboardingDelete").Add_Click({ $self.Trash("Onboardings", "Delete onboarding shell", "onboarding shells") })
        $this.Find("BtnDockerImageDelete").Add_Click({ $self.Trash("DockerImages", "Delete Docker image", "Docker images") })

        $this.Find("BtnRecipeNew").Add_Click({ $self.Vm.NewRecipe() })
        $this.Find("BtnRecipeEdit").Add_Click({ $self.Vm.EditSource("Recipes") })
        $this.Find("BtnRecipeDelete").Add_Click({ $self.Trash("Recipes", "Delete recipe", "recipes") })

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

    hidden [void] Trash([string]$listName, [string]$title, [string]$what) {
        $row = $this.Vm.SelectedRow($listName)
        if (-not $row) { return }
        if (-not $row.Uploaded) { return }
        if (-not $this.ConfirmAs($this, $title, "Remove '$($row.Name)'?", "")) { return }
        $this.Vm.RemoveSelected($listName)
    }
}
