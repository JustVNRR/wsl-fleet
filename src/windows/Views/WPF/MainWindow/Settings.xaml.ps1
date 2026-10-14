# ==============================================================================
# SETTINGS — LA VUE WPF
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewWpf.psm1
using module ..\..\..\Dto\WpfDto.psm1
using module ..\..\..\Dto\PackCatalogDto.psm1
using module ..\..\..\Tools\Helpers.psm1

# La fenêtre Réglages, celle d'aujourd'hui : la racine (montrée ; le crayon
# ouvre la question du déplacement), la face (police, taille, thème, version
# — EN DIRECT), et le catalogue (les packs du dépôt : ouvrir le dossier,
# dupliquer, supprimer). CLOSE rend le look complet — le contrôleur le passe
# entier au service — et le dossier d'arrivée s'il y en a un : c'est l'entrée
# qui le portera au migrate.
#
# Les portes ($doors) : les polices et les thèmes s'écrivent, un pack se
# duplique ou s'efface, un thème s'ouvre — liées au service, la fenêtre n'en
# sait pas plus. Une famille de police voyage en OBJET (une chaîne ne se
# résout pas, mesuré).
class WpfSettingsView : BaseViewWpf {
    # L'Entrée mangée après chaque sélecteur de fichier (mesuré).
    hidden [bool]$EatEnter = $false
    hidden [object]$Doors = $null
    # Le dossier d'arrivée retenu par le crayon de la racine.
    hidden [string]$NewRoot = ""

    [object] Ask([object]$theme, [string[]]$themes, [string[]]$fonts, [object[]]$packs, [string]$root, [string]$assetsDir, [object]$doors) {
        $self = $this
        $this.Doors = $doors
        $this.Title = "Settings"
        $this.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
        $this.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $this.ResizeMode = [System.Windows.ResizeMode]::NoResize
        $this.Load((Join-Path $PSScriptRoot "Settings.xaml"))
        $this.WearTheme($assetsDir, "$($theme.ColorTheme)", "$($theme.Variant)")
        $this.Dress($null, [int]$theme.FontSize)

        $this.Find("TxtLead").Text = "Appearance"

        $txtThemeError = $this.Find("TxtThemeError")
        $txtCatalogueError = $this.Find("TxtCatalogueError")

        # --- la racine -------------------------------------------------------
        $txtRoot = $this.Find("TxtRoot")
        $txtRoot.Text = $root
        $this.Find("BtnGuiRootEdit").Add_Click({
            $chosen = $self.AskRootMove($root)
            if ($chosen) {
                # Le dossier confirmé : la fenêtre s'écarte — le terminal
                # part (le contrôleur), et la face choisie juste avant
                # s'applique en la fermant.
                $self.NewRoot = $chosen
                $txtRoot.Text = $chosen
                $self.Close()
            }
        })

        # --- la face ---------------------------------------------------------
        # La police : les familles reçues, celle qu'on porte marquée et
        # sélectionnée — prépendue quand elle n'y est pas.
        $names = [System.Collections.Generic.List[object]]::new()
        foreach ($font in @($fonts)) { $names.Add("$font") }
        if (-not $names.Contains("$($theme.FontFamily)")) { $names.Insert(0, "$($theme.FontFamily)") }

        $lstFonts = $this.Find("LstGuiFonts")
        $fontIndex = 0
        for ($i = 0; $i -lt $names.Count; $i++) {
            if ($names[$i] -eq "$($theme.FontFamily)") { $fontIndex = $i }
            $null = $lstFonts.Items.Add($names[$i])
        }
        if ($names.Count -gt 0) { $lstFonts.SelectedIndex = $fontIndex }

        $sizes = @(11, 13, 15, 17, 19)
        if ($sizes -notcontains [int]$theme.FontSize) { $sizes = @([int]$theme.FontSize) + $sizes }
        $lstSizes = $this.Find("LstGuiSizes")
        $sizeIndex = 0
        for ($i = 0; $i -lt $sizes.Count; $i++) {
            if ($sizes[$i] -eq [int]$theme.FontSize) { $sizeIndex = $i }
            $null = $lstSizes.Items.Add("$($sizes[$i])")
        }
        $lstSizes.SelectedIndex = $sizeIndex

        $sets = [System.Collections.Generic.List[object]]::new()
        if (-not "$($theme.ColorTheme)" -or @($themes) -notcontains "$($theme.ColorTheme)") { $sets.Add("$($theme.ColorTheme)") }
        foreach ($name in @($themes)) { $sets.Add("$name") }
        $lstColours = $this.Find("LstGuiColours")
        $setIndex = 0
        for ($i = 0; $i -lt $sets.Count; $i++) {
            $label = if ($sets[$i]) { $sets[$i] } else { "Default" }
            if ($sets[$i] -eq "$($theme.ColorTheme)") { $setIndex = $i }
            $null = $lstColours.Items.Add($label)
        }
        $lstColours.SelectedIndex = $setIndex

        # La case « Light » n'est plus offerte : la variante reste celle du
        # thème porté — le bouton de la fenêtre principale la change.
        $variant = "$($theme.Variant)"

        # EN DIRECT : le thème s'échange sous la fenêtre, la police suit.
        # Le crayon et la corbeille d'un thème : grisés sur « Default » — pas
        # de fichier à ouvrir ni à ôter.
        $btnThemeEdit = $this.Find("BtnGuiThemeEdit")
        $btnThemeDelete = $this.Find("BtnGuiThemeDelete")
        $UpdateVariant = {
            $at = $lstColours.SelectedIndex
            $chosen = if ($at -ge 0) { "$($sets[$at])" } else { "" }
            $self.WearTheme($assetsDir, $chosen, $variant)
            $btnThemeEdit.IsEnabled = [bool]$chosen
            $btnThemeDelete.IsEnabled = [bool]$chosen
        }
        $lstColours.Add_SelectionChanged({ & $UpdateVariant })
        $lstFonts.Add_SelectionChanged({
            # Le constructeur, pas une chaîne : une chaîne qui ne se résout
            # pas se convertit en un « rien n'a bougé » que l'œil ne voit pas.
            $self.FontFamily = [Windows.Media.FontFamily]::new("$($lstFonts.SelectedItem)")
        })
        $lstSizes.Add_SelectionChanged({
            # Le visage passé en clair : un visage nul fait retomber Dress sur
            # le statique, et la taille choisie serait ignorée — la fenêtre
            # attendait alors la fermeture (vécu).
            if ($lstSizes.SelectedItem) { $self.Dress($self.FontFamily, [int]$lstSizes.SelectedItem) }
        })
        & $UpdateVariant

        # --- les fichiers des polices et des thèmes --------------------------
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

        # Une police téléversée : le fichier dans son dossier (par la porte),
        # la famille lue LÀ (WPF seul sait la dire), et la ligne ajoutée.
        $this.Find("BtnGuiFontUpload").Add_Click({
            $dialog = New-Object Microsoft.Win32.OpenFileDialog
            $dialog.Title = "A font file for the window"
            $dialog.Filter = "Fonts (*.ttf;*.otf)|*.ttf;*.otf"
            $picked = $dialog.ShowDialog($self)
            $self.EatEnter = $true
            if ($picked -ne $true) { return }
            try { $slot = "$(@($doors.UploadFont.Invoke(@($dialog.FileName)))[0])" } catch { return }
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
            $names.Add($familyName)
            $null = $lstFonts.Items.Add("$familyName  (just uploaded)")
            $lstFonts.SelectedIndex = $lstFonts.Items.Count - 1
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
                $txtThemeError.Text = "The chosen file is not a theme."
                $txtThemeError.Visibility = [System.Windows.Visibility]::Visible
                return
            }
            $txtThemeError.Visibility = [System.Windows.Visibility]::Collapsed
            $existing = -1
            for ($i = 0; $i -lt $sets.Count; $i++) { if ("$($sets[$i])" -eq "$name") { $existing = $i; break } }
            if ($existing -ge 0 -and -not $self.ConfirmAs($self, "Replace theme", "Replace the theme '$name' with the chosen file?", "")) { return }
            try { $null = $doors.UploadTheme.Invoke(@($dialog.FileName)) } catch { return }
            if ($existing -lt 0) {
                $sets.Add($name)
                $null = $lstColours.Items.Add("$name  (just uploaded)")
                $existing = $sets.Count - 1
            }
            $lstColours.SelectedIndex = $existing
        })

        # Le téléchargement : le fichier du thème — ou, pour « Default », le
        # chart que cette fenêtre connaît.
        $this.Find("BtnGuiThemeDownload").Add_Click({
            $at = $lstColours.SelectedIndex
            if ($at -lt 0) { return }
            $name = "$($sets[$at])"
            $file = if ($name) { Join-Path (Join-Path $assetsDir "themes") "$name.xaml" } else { Join-Path (Split-Path -Path $PSScriptRoot -Parent) "theme.xaml" }
            $proposed = if ($name) { "$name.xaml" } else { "theme.xaml" }
            $save = New-Object Microsoft.Win32.SaveFileDialog
            $save.Title = "Save '$proposed'"
            $save.FileName = $proposed
            $save.Filter = "All files (*.*)|*.*"
            $picked = $save.ShowDialog($self)
            $self.EatEnter = $true
            if ($picked -ne $true) { return }
            try {
                $exp = [ExportThemeDto]::new()
                $exp.Source = $file
                $exp.Target = $save.FileName
                $null = $doors.ExportTheme.Invoke(@($exp))
            } catch { }
        })

        # La corbeille d'un thème : confirmée, la porte l'ôte, la liste suit.
        $this.Find("BtnGuiThemeDelete").Add_Click({
            $at = $lstColours.SelectedIndex
            if ($at -lt 0) { return }
            $name = "$($sets[$at])"
            if (-not $name) { return }
            if (-not $self.ConfirmAs($self, "Delete theme", "Remove the theme '$name'?", "")) { return }
            try { $null = $doors.DeleteTheme.Invoke(@($name)) } catch { return }
            $sets.RemoveAt($at)
            $lstColours.Items.RemoveAt($at)
            if ($lstColours.Items.Count -gt 0) { $lstColours.SelectedIndex = [Math]::Min($at, $lstColours.Items.Count - 1) }
            & $UpdateVariant
        })

        # Le crayon d'un thème : son fichier ouvert comme Windows ouvre les
        # fichiers. Un refus s'écrit sur la ligne rouge.
        $this.Find("BtnGuiThemeEdit").Add_Click({
            $at = $lstColours.SelectedIndex
            if ($at -lt 0) { return }
            $name = "$($sets[$at])"
            if (-not $name) { return }
            try { $null = $doors.OpenTheme.Invoke(@($name)) } catch {
                $txtThemeError.Text = "The file did not open: $($_.Exception.Message)"
                $txtThemeError.Visibility = [System.Windows.Visibility]::Visible
            }
        })

        # --- le catalogue ----------------------------------------------------
        $lstPacks = $this.Find("LstGuiPacks")
        $btnPackEdit = $this.Find("BtnGuiPackEdit")
        $btnPackDuplicate = $this.Find("BtnGuiPackDuplicate")
        $btnPackDelete = $this.Find("BtnGuiPackDelete")
        $packRows = [System.Collections.Generic.List[object]]::new()
        # La liste, redessinée à la demande : les gestes la rafraîchissent en
        # place.
        $RefreshPacks = {
            $packRows.Clear()
            $lstPacks.Items.Clear()
            foreach ($pack in @($packs | Sort-Object Name)) {
                $packRows.Add($pack)
                $null = $lstPacks.Items.Add("$($pack.Name) ($($pack.Family))")
            }
        }
        $UpdatePacks = {
            $has = $lstPacks.SelectedIndex -ge 0
            $btnPackEdit.IsEnabled = $has
            $btnPackDuplicate.IsEnabled = $has
            $btnPackDelete.IsEnabled = $has
        }
        & $RefreshPacks
        if ($lstPacks.Items.Count -gt 0) { $lstPacks.SelectedIndex = 0 }
        $lstPacks.Add_SelectionChanged({ & $UpdatePacks })
        & $UpdatePacks

        $this.Find("BtnGuiPackEdit").Add_Click({
            if ($lstPacks.SelectedIndex -lt 0) { return }
            try { $null = $doors.PackOpen.Invoke(@("$($packRows[$lstPacks.SelectedIndex].Name)")) } catch {
                $txtCatalogueError.Text = "The folder did not open: $($_.Exception.Message)"
                $txtCatalogueError.Visibility = [System.Windows.Visibility]::Visible
            }
        })

        # Dupliquer : la petite fenêtre (le nom, la description), puis la
        # porte copie le dossier sous le nom neuf.
        $this.Find("BtnGuiPackDuplicate").Add_Click({
            $at = $lstPacks.SelectedIndex
            if ($at -lt 0) { return }
            $pack = $packRows[$at]
            $taken = @($packRows | ForEach-Object { "$($_.Name)" })
            $answer = $self.AskPackDuplicate("$($pack.Name)", "$($pack.Description)", $taken)
            if ($null -eq $answer) { return }
            try {
                $dto = [CreatePackDto]::new()
                $dto.SourceName = "$($pack.Name)"
                $dto.NewName = "$($answer.Name)"
                $dto.Description = "$($answer.Description)"
                $null = $doors.PackDuplicate.Invoke(@($dto))
            } catch {
                $txtCatalogueError.Text = "The pack was not duplicated: $($_.Exception.Message)"
                $txtCatalogueError.Visibility = [System.Windows.Visibility]::Visible
                return
            }
            # La liste relue : le catalogue a changé sous elle.
            $refreshed = @($doors.PackRefresh.Invoke(@()))
            $packRows.Clear()
            $lstPacks.Items.Clear()
            foreach ($one in @($refreshed | Sort-Object Name)) {
                $packRows.Add($one)
                $null = $lstPacks.Items.Add("$($one.Name) ($($one.Family))")
            }
            $copyAt = 0
            for ($i = 0; $i -lt $packRows.Count; $i++) { if ("$($packRows[$i].Name)" -eq "$($answer.Name)") { $copyAt = $i; break } }
            if ($lstPacks.Items.Count -gt 0) { $lstPacks.SelectedIndex = $copyAt }
            & $UpdatePacks
        })

        # Supprimer : la porte rouge, puis la porte ôte le dossier entier ; la
        # liste relue. Ce qui dépendait du pack est l'affaire du catalogue —
        # les instances qui le portent gardent leur copie.
        $this.Find("BtnGuiPackDelete").Add_Click({
            $at = $lstPacks.SelectedIndex
            if ($at -lt 0) { return }
            $pack = $packRows[$at]
            if (-not $self.ConfirmAs($self, "Remove the pack", "Remove the pack '$($pack.Name)'?`n`nInstances already carrying it keep their own copy.", "")) { return }
            try { $null = $doors.PackDelete.Invoke(@("$($pack.Name)")) } catch {
                $txtCatalogueError.Text = "The pack was not removed: $($_.Exception.Message)"
                $txtCatalogueError.Visibility = [System.Windows.Visibility]::Visible
                return
            }
            $refreshed = @($doors.PackRefresh.Invoke(@()))
            $packRows.Clear()
            $lstPacks.Items.Clear()
            foreach ($one in @($refreshed | Sort-Object Name)) {
                $packRows.Add($one)
                $null = $lstPacks.Items.Add("$($one.Name) ($($one.Family))")
            }
            if ($lstPacks.Items.Count -gt 0) { $lstPacks.SelectedIndex = 0 }
            & $UpdatePacks
        })

        $this.Find("BtnGuiClose").Add_Click({ $self.Close() })

        $this.FitToContent($null)
        $null = $this.OpenAs($null)

        # Le look choisi — le contrôleur le passe entier — et le dossier
        # d'arrivée, s'il y en a un. Le contexte des fenêtres se rafraîchit
        # ici : les prochaines s'ouvriront avec la face choisie.
        $picked = [PSCustomObject]@{
            FontFamily = "$($names[[Math]::Max(0, $lstFonts.SelectedIndex)])"
            FontSize   = [int]$lstSizes.SelectedItem
            ColorTheme = if ($lstColours.SelectedIndex -ge 0) { "$($sets[$lstColours.SelectedIndex])" } else { "" }
            Variant    = "$($theme.Variant)"
            NewRoot    = $this.NewRoot
        }
        $look = [WpfThemeDto]::new()
        $look.FontFamily = $picked.FontFamily
        $look.FontSize = $picked.FontSize
        $look.ColorTheme = $picked.ColorTheme
        $look.Variant = $picked.Variant
        [BaseViewWpf]::SetContext($look, $assetsDir)
        return $picked
    }

    # La question du déplacement de la racine : l'avertissement, le dossier
    # d'arrivée, Cancel et le CONFIRM rouge. Rend le dossier, ou rien. Le
    # déménagement lui-même — archiver, désinscrire — n'est pas ici : c'est
    # l'entrée qui le portera au migrate.
    hidden [string] AskRootMove([string]$current) {
        $move = [BaseViewWpf]::new()
        $move.Title = "WSL Stack"
        $move.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
        $move.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $move.ResizeMode = [System.Windows.ResizeMode]::NoResize
        $move.Load((Join-Path (Split-Path -Path $PSScriptRoot -Parent) "shared\RootMove.xaml"))
        $move.WearDefault()
        $move.Dress($null, 15)

        $move.Find("TxtLead").Text = "Move the fleet from '$current'"
        $move.Find("TxtWarning").Text = "Every instance will be archived and unregistered before migration."
        $txtNewRoot = $move.Find("TxtNewRoot")
        $txtNewRoot.Text = $current
        $move.Add_ContentRendered({ $null = $txtNewRoot.Focus(); $txtNewRoot.SelectAll() })

        $move.Find("BtnRootCancel").Add_Click({ $move.Close() })
        $move.Find("BtnRootOk").Add_Click({
            $chosen = "$($txtNewRoot.Text)".Trim().Trim('"').TrimEnd('\')
            if (-not $chosen -or $chosen -eq "$current".TrimEnd('\')) { return }
            # La garde du service, montrée ici : la boîte reste ouverte et dit
            # pourquoi — rien ne part pour un chemin impossible.
            $problem = Test-FleetTarget $chosen
            if ($problem) {
                $move.Find("TxtWarning").Text = $problem
                return
            }
            $move.Result = $chosen
            $move.Close()
        })

        $move.FitToContent($this)
        $null = $move.OpenAs($this)
        return "$($move.Result)"
    }

    # La petite fenêtre de duplication : le nom (source-copy proposé, pris
    # refusé) et la description.
    hidden [object] AskPackDuplicate([string]$source, [string]$description, [string[]]$taken) {
        $dup = [BaseViewWpf]::new()
        $dup.Title = "WSL Stack"
        $dup.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
        $dup.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $dup.ResizeMode = [System.Windows.ResizeMode]::NoResize
        $dup.Load((Join-Path (Split-Path -Path $PSScriptRoot -Parent) "shared\PackDuplicate.xaml"))
        $dup.WearDefault()
        $dup.Dress($null, 15)

        $dup.Find("TxtLead").Text = "Duplicate the pack '$source'"
        $txtDupName = $dup.Find("TxtDupName")
        $txtDupName.Text = "$source-copy"
        $dup.Find("TxtDupDescription").Text = $description
        $txtDupError = $dup.Find("TxtDupError")
        $dup.Add_ContentRendered({ $null = $txtDupName.Focus(); $txtDupName.SelectAll() })

        $dup.Find("BtnDupCancel").Add_Click({ $dup.Close() })
        $dup.Find("BtnDupOk").Add_Click({
            $chosen = "$($txtDupName.Text)".Trim()
            $problem = ""
            if ($chosen -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*$') {
                $problem = "Letters, digits, '.', '_' and '-' only, starting with a letter or a digit."
            } elseif (@($taken | Where-Object { $_ -eq $chosen }).Count -gt 0) {
                $problem = "A pack named '$chosen' already exists."
            }
            if ($problem) {
                $txtDupError.Text = $problem
                $txtDupError.Visibility = [System.Windows.Visibility]::Visible
                return
            }
            $dup.Result = [PSCustomObject]@{ Name = $chosen; Description = "$($dup.Find("TxtDupDescription").Text)".Trim() }
            $dup.Close()
        })

        $dup.FitToContent($this)
        $null = $dup.OpenAs($this)
        return $dup.Result
    }
}
