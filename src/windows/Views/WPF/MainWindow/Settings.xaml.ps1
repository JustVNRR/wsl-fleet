using module ..\BaseViewWpf.psm1
using module ..\..\..\Dtos\WpfDto.psm1
using module ..\..\..\ViewModels\SettingsViewModel.psm1

class WpfSettingsView : BaseViewWpf {

    hidden [bool]$EatEnter = $false
    hidden [object]$Vm = $null
    hidden [string]$AssetsDir = ""

    [object] Ask([object]$wpfService, [object]$catalogueService, [object]$fleetService, [string]$assetsDir) {
        $self = $this
        $this.AssetsDir = $assetsDir
        $this.Vm = [SettingsViewModel]::new($wpfService, $catalogueService, $fleetService, $assetsDir)

        $viewsRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $this.Vm.Ouverture = {
            param($gesture, $arguments)
            return $self.Vm.FindFace($viewsRoot, $gesture, $arguments)
        }

        $this.Title = "Settings"
        $this.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
        $this.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $this.ResizeMode = [System.Windows.ResizeMode]::NoResize
        $this.Load((Join-Path $PSScriptRoot "Settings.xaml"))
        $this.WearDefault()
        $this.Dress($null, 15)
        $this.DataContext = $this.Vm

        $this.Vm.DemandeFermeture = { param($result) $self.Result = $result; $self.Close() }

        $this.Vm.add_PropertyChanged({
            param($source, $e)
            switch ("$($e.PropertyName)") {
                "FontIndex" { $self.RepaintFace() }
                "SizeIndex" { $self.RepaintFace() }
                "ColourIndex" { $self.RepaintFace() }
                "ThemeError" { $self.ShowError("GuiThemeError", "$($source.ThemeError)") }
                "CatalogueError" { $self.ShowError("GuiCatalogueError", "$($source.CatalogueError)") }
                "ConfigError" { $self.ShowError("GuiConfigError", "$($source.ConfigError)") }
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

        $this.Find("LstGuiFonts").Add_SelectionChanged({ param($source, $e) if ([int]$source.SelectedIndex -ge 0) { $self.Vm.SetFontIndex([int]$source.SelectedIndex) } })
        $this.Find("LstGuiSizes").Add_SelectionChanged({ param($source, $e) if ([int]$source.SelectedIndex -ge 0) { $self.Vm.SetSizeIndex([int]$source.SelectedIndex) } })
        $this.Find("LstGuiColours").Add_SelectionChanged({ param($source, $e) if ([int]$source.SelectedIndex -ge 0) { $self.Vm.SetColourIndex([int]$source.SelectedIndex) } })
        $this.Find("LstGuiPacks").Add_SelectionChanged({ param($source, $e) if ([int]$source.SelectedIndex -ge 0) { $self.Vm.SetPackIndex([int]$source.SelectedIndex) } })

        $this.Find("BtnGuiRootEdit").Add_Click({ $self.Vm.EditRoot() })
        $this.Find("BtnGuiWslConfig").Add_Click({ $self.Vm.WslConfig() })

        $this.Find("BtnGuiFontUpload").Add_Click({
            $dialog = New-Object Microsoft.Win32.OpenFileDialog
            $dialog.Title = "A font file for the window"
            $dialog.Filter = "Fonts (*.ttf;*.otf)|*.ttf;*.otf"
            $picked = $dialog.ShowDialog($self)
            $self.EatEnter = $true
            if ($picked -ne $true) { return }
            $slot = $self.Vm.UploadFont($dialog.FileName)
            if (-not $slot) { return }
            $familyName = ""
            try {
                $uri = [Uri]("file:///" + ($slot -replace '\\', '/') + "/")
                $family = @([Windows.Media.Fonts]::GetFontFamilies($uri) | Select-Object -First 1)
                if ($family.Count -gt 0) {
                    $familyName = "$($family[0].FamilyNames.Values | Select-Object -First 1)"
                    if (-not $familyName) { $familyName = "$($family[0].Source)" -replace '^\./#', '' }
                }
            } catch { }
            if (-not $familyName) { return }
            $self.Vm.AddFont($familyName)
        })

        $this.Find("BtnGuiThemeUpload").Add_Click({
            $dialog = New-Object Microsoft.Win32.OpenFileDialog
            $dialog.Title = "A theme file for the windows"
            $dialog.Filter = "Themes (*.xaml)|*.xaml"
            $picked = $dialog.ShowDialog($self)
            $self.EatEnter = $true
            if ($picked -ne $true) { return }
            $name = [IO.Path]::GetFileNameWithoutExtension($dialog.FileName)
            $loads = $false
            try {
                $loaded = [Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new([xml][System.IO.File]::ReadAllText($dialog.FileName)))
                $loads = $loaded -is [System.Windows.ResourceDictionary]
            } catch { }
            if (-not ($loads -and $name)) {
                $self.Vm.FailTheme("The chosen file is not a theme.")
                return
            }
            $self.Vm.ClearThemeError()
            if ($self.Vm.HasTheme("$name") -and -not $self.ConfirmAs($self, "Replace theme", "Replace the theme '$name' with the chosen file?", "")) { return }
            $self.Vm.UploadTheme($dialog.FileName, "$name")
        })

        $this.Find("BtnGuiThemeDownload").Add_Click({
            $name = $self.Vm.SelectedColour()
            $proposed = $self.Vm.ThemeFileFor($name)
            $save = New-Object Microsoft.Win32.SaveFileDialog
            $save.Title = "Save '$proposed'"
            $save.FileName = $proposed
            $save.Filter = "All files (*.*)|*.*"
            $picked = $save.ShowDialog($self)
            $self.EatEnter = $true
            if ($picked -ne $true) { return }
            $self.Vm.ExportTheme($name, $save.FileName)
        })

        $this.Find("BtnGuiThemeDelete").Add_Click({
            $name = $self.Vm.SelectedColour()
            if (-not $name) { return }
            if (-not $self.ConfirmAs($self, "Delete theme", "Remove '$name'?", "")) { return }
            $self.Vm.DeleteTheme($name)
        })

        $this.Find("BtnGuiThemeEdit").Add_Click({
            $self.Vm.OpenTheme($self.Vm.SelectedColour())
        })

        $this.Find("BtnGuiPackEdit").Add_Click({ $self.Vm.OpenPack() })
        $this.Find("BtnGuiPackDuplicate").Add_Click({ $self.Vm.DuplicatePack() })
        $this.Find("BtnGuiPackDelete").Add_Click({
            $row = $self.Vm.SelectedPack()
            if (-not $row) { return }
            $question = "Remove the pack '$($row.Name)'?"
            $danger = ""
            $dependents = @($row.Dependents)
            if ($dependents.Count -gt 0) {
                $question += "`n`nThese packs depend on it:"
                $question += "`n" + (@($dependents | ForEach-Object { "- $_" }) -join "`n")
                $danger = "Removing it may break them."
            }
            if (-not $self.ConfirmAs($self, "Remove the pack", $question, $danger)) { return }
            $self.Vm.DeletePack()
        })

        $this.Find("BtnGuiClose").Add_Click({ $self.Close() })

        $this.FitToContent($null)
        $null = $this.OpenAs($null)

        $picked = $this.Vm.Picked()
        $look = [WpfThemeDto]::new()
        $look.FontFamily = $picked.FontFamily
        $look.FontSize = $picked.FontSize
        $look.ColorTheme = $picked.ColorTheme
        $look.Variant = $picked.Variant
        [BaseViewWpf]::SetContext($look, $assetsDir)
        return $picked
    }

    hidden [void] RepaintFace() {
        $family = $this.Vm.SelectedFont()
        if ($family) { $this.FontFamily = [Windows.Media.FontFamily]::new("$family") }
        $this.WearTheme($this.AssetsDir, "$($this.Vm.SelectedColour())", "$($this.Vm.Variant)")
        $this.Dress($this.FontFamily, [int]$this.Vm.SelectedSize())
    }
}
