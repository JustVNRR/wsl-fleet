# ==============================================================================
# SETTINGS — LA VUE WPF
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewWpf.psm1
using module ..\..\..\Dto\WpfDto.psm1
using module ..\..\..\ViewModels\SettingsViewModel.psm1

# La fenêtre Réglages : le DataContext est le SettingsViewModel — la racine,
# les trois listes, le catalogue et leurs mains se bindent en XAML. Ici, ce
# que WPF demande : la FACE EN DIRECT (la vue se repeint sur les choix — la
# famille se construit en objet, mesuré), les sélecteurs de fichiers et la
# lecture de la famille d'une police (WPF seul sait la dire), le jugement d'un
# thème téléversé (WPF seul sait lire un dictionnaire), les portes rouges, la
# porte de fermeture — et le contexte des fenêtres rafraîchi en sortant, sur
# le look rendu.
class WpfSettingsView : BaseViewWpf {
    # L'Entrée mangée après chaque sélecteur de fichier (mesuré).
    hidden [bool]$EatEnter = $false
    hidden [object]$Vm = $null
    hidden [string]$AssetsDir = ""

    [object] Ask([object]$wpfService, [object]$catalogueService, [object]$fleetService, [string]$assetsDir) {
        $self = $this
        $this.AssetsDir = $assetsDir
        $this.Vm = [SettingsViewModel]::new($wpfService, $catalogueService, $fleetService, $assetsDir)

        # La porte d'ouverture : la vue dit où et comment on trouve une boîte
        # (son propre dossier), le ViewModel ne dit que « ouvre la boîte X ».
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

        # La porte de fermeture — METHODE 1 : le ViewModel dit « j'ai fini »,
        # la vue ferme.
        $this.Vm.DemandeFermeture = { param($result) $self.Result = $result; $self.Close() }

        # La face en direct : le thème s'échange sous la fenêtre, la police
        # suit, la taille se redresse.
        $this.Vm.add_PropertyChanged({
            param($source, $e)
            switch ("$($e.PropertyName)") {
                "FontIndex" { $self.RepaintFace() }
                "SizeIndex" { $self.RepaintFace() }
                "ColourIndex" { $self.RepaintFace() }
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

        # Les choix : liens à sens unique — la vue relaie chaque sélection au
        # ViewModel, qui crie et fait repeindre la face.
        $this.Find("LstGuiFonts").Add_SelectionChanged({ param($source, $e) $self.Vm.SetFontIndex([int]$source.SelectedIndex) })
        $this.Find("LstGuiSizes").Add_SelectionChanged({ param($source, $e) $self.Vm.SetSizeIndex([int]$source.SelectedIndex) })
        $this.Find("LstGuiColours").Add_SelectionChanged({ param($source, $e) $self.Vm.SetColourIndex([int]$source.SelectedIndex) })
        $this.Find("LstGuiPacks").Add_SelectionChanged({ param($source, $e) $self.Vm.SetPackIndex([int]$source.SelectedIndex) })

        $this.Find("BtnGuiRootEdit").Add_Click({ $self.Vm.EditRoot() })

        # Une police téléversée : le fichier posé par le ViewModel (au
        # service), la famille lue LÀ (WPF seul sait la dire), et la ligne
        # ajoutée.
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

        # Un thème téléversé : le fichier doit se charger comme dictionnaire
        # (WPF seul sait le dire), un nom pris se remplace après accord. Un
        # refus s'écrit sur la ligne rouge, il ne tue pas la fenêtre.
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

        # Le téléchargement : le fichier du thème — ou, pour « Default », le
        # chart que cette fenêtre connaît.
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

        # La corbeille d'un thème : confirmée, le ViewModel l'ôte, la liste
        # suit.
        $this.Find("BtnGuiThemeDelete").Add_Click({
            $name = $self.Vm.SelectedColour()
            if (-not $name) { return }
            if (-not $self.ConfirmAs($self, "Delete theme", "Remove the theme '$name'?", "")) { return }
            $self.Vm.DeleteTheme($name)
        })

        # Le crayon d'un thème : son fichier ouvert comme Windows ouvre les
        # fichiers. Un refus s'écrit sur la ligne rouge.
        $this.Find("BtnGuiThemeEdit").Add_Click({
            $self.Vm.OpenTheme($self.Vm.SelectedColour())
        })

        # Le catalogue : ouvrir le dossier, dupliquer (sa petite fenêtre),
        # supprimer (la porte rouge d'abord).
        $this.Find("BtnGuiPackEdit").Add_Click({ $self.Vm.OpenPack() })
        $this.Find("BtnGuiPackDuplicate").Add_Click({ $self.Vm.DuplicatePack() })
        $this.Find("BtnGuiPackDelete").Add_Click({
            $row = $self.Vm.SelectedPack()
            if (-not $row) { return }
            if (-not $self.ConfirmAs($self, "Remove the pack", "Remove the pack '$($row.Name)'?`n`nInstances already carrying it keep their own copy.", "")) { return }
            $self.Vm.DeletePack()
        })

        $this.Find("BtnGuiClose").Add_Click({ $self.Close() })

        $this.FitToContent($null)
        $null = $this.OpenAs($null)

        # Le look choisi — le ViewModel le rend entier — et le dossier
        # d'arrivée, s'il y en a un. Le contexte des fenêtres se rafraîchit
        # ici : les prochaines s'ouvriront avec la face choisie.
        $picked = $this.Vm.Picked()
        $look = [WpfThemeDto]::new()
        $look.FontFamily = $picked.FontFamily
        $look.FontSize = $picked.FontSize
        $look.ColorTheme = $picked.ColorTheme
        $look.Variant = $picked.Variant
        [BaseViewWpf]::SetContext($look, $assetsDir)
        return $picked
    }

    # La face se repeint sur les choix du ViewModel — la famille en OBJET
    # (une chaîne ne se résout pas, mesuré).
    hidden [void] RepaintFace() {
        $family = $this.Vm.SelectedFont()
        if ($family) { $this.FontFamily = [Windows.Media.FontFamily]::new("$family") }
        $this.WearTheme($this.AssetsDir, "$($this.Vm.SelectedColour())", "$($this.Vm.Variant)")
        $this.Dress($this.FontFamily, [int]$this.Vm.SelectedSize())
    }
}
