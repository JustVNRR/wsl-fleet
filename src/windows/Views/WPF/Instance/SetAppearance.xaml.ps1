# ==============================================================================
# SETAPPEARANCE — LA VUE WPF
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewWpf.psm1
using module ..\..\..\Dto\InstanceDto.psm1

# Le look d'une instance, la même fenêtre qu'aujourd'hui : les lettres et les
# paires de la tuile, une image à soi, la police et le schéma de couleurs —
# avec l'aperçu qui se repeint (les lignes du prompt, la palette, l'image
# choisie). Rien ne s'applique ici : APPLY rend le SetAppearanceDto, le
# contrôleur appelle le service.
#
# Une simplification assumée (la même qu'au cli) : la tuile ne se dessine plus
# à chaque tour — une vue ne lance pas make-icon. L'aperçu de la tuile montre
# l'image CHOISIE (le fichier, ses octets) ; la recette se dessinera une fois,
# à l'application.
#
# L'image prend le siège et le dessin reste derrière : une retouche des
# lettres ou des couleurs reprend le siège (l'image s'efface), comme
# aujourd'hui.
class WpfSetAppearanceView : BaseViewWpf {
    # Le fichier choisi par Upload — il prend le siège ; une retouche du
    # dessin l'efface. Une propriété, pas une locale : les poignées écrivent.
    hidden [string]$ChosenImage = ""
    # L'Entrée mangée après la fermeture du sélecteur de fichier (mesuré :
    # sans quoi elle retombe sur APPLY et ferme la fenêtre).
    hidden [bool]$EatEnter = $false

    [object] Ask([string]$name, [object]$appearance, [string[]]$fonts, [object[]]$schemes, [object[]]$pairs) {
        $self = $this
        $this.Title = "Appearance"
        $this.Width = 600
        $this.SizeToContent = [System.Windows.SizeToContent]::Height
        $this.MaxHeight = 760
        $this.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $this.ResizeMode = [System.Windows.ResizeMode]::NoResize
        $this.Load((Join-Path $PSScriptRoot "SetAppearance.xaml"))
        $this.WearDefault()
        $this.Dress($null, 15)

        $this.Find("TxtLead").Text = "$name's appearance."
        if (-not $appearance.HasFragment) { $this.Find("TxtNoFragment").Visibility = [System.Windows.Visibility]::Visible }

        # La recette en main : ce que la tuile est — les champs d'en dessous
        # partent de là, une retouche change un morceau.
        $recipe = $appearance.Icon

        # La tuile : les lettres, et les paires offertes — la paire en place
        # marquée. Chaque paire est montrée avec les lettres en main : deux
        # codes hexadécimaux ne disent rien à l'œil.
        $txtIcon = $this.Find("TxtIconText")
        $txtIcon.Text = "$($recipe.Text)"
        $txtIconError = $this.Find("TxtIconError")
        $lstPairs = $this.Find("LstPairs")
        $pairRows = @($pairs)
        $pairIndex = 0
        for ($i = 0; $i -lt $pairRows.Count; $i++) {
            $here = if ($recipe -and $pairRows[$i].Top -eq $recipe.Top -and $pairRows[$i].Bottom -eq $recipe.Bottom) { "  (current)" } else { "" }
            if ($here) { $pairIndex = $i }
            $null = $lstPairs.Items.Add("$($pairRows[$i].Name)$here")
        }
        if ($pairRows.Count -gt 0) { $lstPairs.SelectedIndex = $pairIndex }

        $txtIcon.Add_TextChanged({
            # La règle des lettres, dite sous la boîte : jusqu'à trois,
            # lettres ou chiffres.
            $ok = ("$($txtIcon.Text)" -match '^[A-Za-z0-9]{1,3}$')
            $txtIconError.Text = if ($ok) { "" } else { "One to three letters or digits." }
            $txtIconError.Visibility = if ($ok) { [System.Windows.Visibility]::Collapsed } else { [System.Windows.Visibility]::Visible }
        })

        # La police : la liste reçue, celle en place marquée et sélectionnée —
        # et prépendue quand elle n'y est pas : une liste qui l'ignore ment
        # sur ce que l'instance porte.
        $fontNames = [System.Collections.Generic.List[object]]::new()
        foreach ($font in @($fonts)) { $fontNames.Add("$font") }
        if (-not $fontNames.Contains("$($appearance.Font)")) { $fontNames.Insert(0, "$($appearance.Font)") }
        $lstFonts = $this.Find("LstFonts")
        $fontIndex = 0
        for ($i = 0; $i -lt $fontNames.Count; $i++) {
            $here = if ($fontNames[$i] -eq "$($appearance.Font)") { "  (current)" } else { "" }
            if ($here) { $fontIndex = $i }
            $null = $lstFonts.Items.Add("$($fontNames[$i])$here")
        }
        if ($fontNames.Count -gt 0) { $lstFonts.SelectedIndex = $fontIndex }

        # Le schéma : la liste reçue, celui en place marqué et sélectionné.
        $schemeRows = @($schemes | Sort-Object Name)
        $lstSchemes = $this.Find("LstSchemes")
        $schemeIndex = 0
        for ($i = 0; $i -lt $schemeRows.Count; $i++) {
            $here = if ($schemeRows[$i].Name -eq "$($appearance.ColourScheme)") { "  (current)" } else { "" }
            if ($here) { $schemeIndex = $i }
            $null = $lstSchemes.Items.Add("$($schemeRows[$i].Name)$here")
        }
        if ($schemeRows.Count -gt 0) { $lstSchemes.SelectedIndex = $schemeIndex }

        # L'aperçu : les lignes du prompt dans la police choisie, peintes des
        # couleurs du schéma, la palette des seize dessous — choisir à
        # l'aveugle était la première critique de cette fenêtre.
        $brdPreview = $this.Find("BrdPreview")
        $previewLines = @($this.Find("TxtPreview1"), $this.Find("TxtPreview2"), $this.Find("TxtPreview3"),
            $this.Find("TxtPreview4"), $this.Find("TxtPreview5"), $this.Find("TxtPreview6"))
        $pnlPalette = $this.Find("PnlPalette")
        $slotByIndex = @("Black", "DarkRed", "DarkGreen", "DarkYellow", "DarkBlue", "DarkMagenta", "DarkCyan", "Gray",
            "DarkGray", "Red", "Green", "Yellow", "Blue", "Magenta", "Cyan", "White")

        $UpdatePreview = {
            $fontName = if ($fontNames.Count -gt 0) { "$($fontNames[[Math]::Max(0, $lstFonts.SelectedIndex)])" } else { "$($appearance.Font)" }
            if ($fontName) {
                # Le constructeur, pas une chaîne : une chaîne qui ne se
                # résout pas se convertit en un « rien n'a bougé » que l'œil
                # ne voit pas.
                $family = [Windows.Media.FontFamily]::new("$fontName")
                foreach ($line in $previewLines) { $line.FontFamily = $family }
            }

            $scheme = $null
            if ($schemeRows.Count -gt 0) { $scheme = $schemeRows[[Math]::Max(0, $lstSchemes.SelectedIndex)] }
            $bg = $null
            $fg = $null
            if ($scheme) {
                $bg = $self.Brush("$($scheme.Background)")
                $fg = $self.Brush("$($scheme.Foreground)")
            }
            $brdPreview.Background = if ($bg) { $bg } else { $self.Brush("#0C0C0C") }
            foreach ($line in $previewLines) {
                $line.Foreground = if ($fg) { $fg } else { $self.Brush("#33FF66") }
                foreach ($run in @($line.Inlines)) {
                    $brush = $null
                    if ("$($run.Tag)" -eq 'fg') {
                        $brush = if ($fg) { $fg } else { $self.Brush("#33FF66") }
                    } elseif ("$($run.Tag)" -match '^c(\d+)$') {
                        $idx = [int]$Matches[1]
                        if ($scheme -and $idx -lt $slotByIndex.Count) { $brush = $self.Brush("$($scheme.$($slotByIndex[$idx]))") }
                    }
                    if ($brush) { $run.Foreground = $brush }
                }
            }

            $pnlPalette.Children.Clear()
            if ($scheme) {
                foreach ($slotName in $slotByIndex) {
                    $brush = $self.Brush("$($scheme.$slotName)")
                    if (-not $brush) { continue }
                    $swatch = New-Object System.Windows.Controls.Border
                    $swatch.Width = 18
                    $swatch.Height = 12
                    $swatch.Margin = "0,0,2,0"
                    $swatch.Background = $brush
                    $null = $pnlPalette.Children.Add($swatch)
                }
            }
        }
        $lstFonts.Add_SelectionChanged({ & $UpdatePreview })
        $lstSchemes.Add_SelectionChanged({ & $UpdatePreview })
        & $UpdatePreview

        # L'image choisie : son aperçu se lit du FICHIER (ses octets), avec
        # les deux options mesurées — OnLoad (le fichier est lu entier et
        # lâché) et IgnoreImageCache (WPF garde les images décodées par URI,
        # et l'aperçu d'une nouvelle sélection du même chemin ne bougerait
        # pas).
        $imgPreview = $this.Find("ImgIconPreview")
        $txtIconPath = $this.Find("TxtIconPath")
        $LoadIconFile = {
            param([string]$path)
            try {
                $bmp = New-Object Windows.Media.Imaging.BitmapImage
                $bmp.BeginInit()
                $bmp.CreateOptions = [Windows.Media.Imaging.BitmapCreateOptions]::IgnoreImageCache
                $bmp.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
                $bmp.UriSource = [Uri]"$path"
                $bmp.EndInit()
                $imgPreview.Source = $bmp
            } catch { }
        }

        # L'image en place — le siège de l'icône, quand une y est posée :
        # l'aperçu la montre, et APPLY la garde. Une retouche des lettres ou
        # des paires reprend le siège.
        if ("$($appearance.IconPath)" -and (Test-Path "$($appearance.IconPath)")) {
            $self.ChosenImage = "$($appearance.IconPath)"
            $txtIconPath.Text = "$($appearance.IconPath)"
            $txtIconPath.ToolTip = "$($appearance.IconPath)"
            & $LoadIconFile "$($appearance.IconPath)"
        }
        $txtIcon.Add_TextChanged({ $self.ChosenImage = "" })
        $lstPairs.Add_SelectionChanged({ $self.ChosenImage = "" })

        # L'Entrée mangée après le sélecteur : à sa fermeture, l'Entrée
        # retombe sur le bouton par défaut — APPLY a déjà fermé cette fenêtre
        # une fois (mesuré).
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

        $this.Find("BtnImage").Add_Click({
            $dialog = New-Object Microsoft.Win32.OpenFileDialog
            $dialog.Title = "Icon image for '$name'"
            $dialog.Filter = "Images (*.png;*.jpg;*.jpeg;*.ico;*.bmp)|*.png;*.jpg;*.jpeg;*.ico;*.bmp"
            $picked = $dialog.ShowDialog($self)
            $self.EatEnter = $true
            if ($picked -eq $true) {
                $self.ChosenImage = $dialog.FileName
                $txtIconPath.Text = $dialog.FileName
                $txtIconPath.ToolTip = $dialog.FileName
                & $LoadIconFile $dialog.FileName
            }
        })

        $this.Find("BtnLookCancel").Add_Click({ $self.Result = $null; $self.Close() })
        $this.Find("BtnLookApply").Add_Click({
            # Les lettres sont la seule règle de la tuile ; les listes
            # répondent d'elles-mêmes.
            if ("$($txtIcon.Text)" -notmatch '^[A-Za-z0-9]{1,3}$') { return }

            $dto = [SetAppearanceDto]::new()
            $dto.InstanceName = $name
            $dto.Font = if ($fontNames.Count -gt 0) { "$($fontNames[[Math]::Max(0, $lstFonts.SelectedIndex)])" } else { "$($appearance.Font)" }
            $dto.ColourScheme = if ($schemeRows.Count -gt 0) { "$($schemeRows[[Math]::Max(0, $lstSchemes.SelectedIndex)].Name)" } else { "$($appearance.ColourScheme)" }

            $icon = [WslIconDto]::new()
            $icon.Text = "$($txtIcon.Text)".ToUpper()
            $pair = if ($pairRows.Count -gt 0) { $pairRows[[Math]::Max(0, $lstPairs.SelectedIndex)] } else { $null }
            $icon.Top = if ($pair) { "$($pair.Top)" } elseif ($recipe) { "$($recipe.Top)" } else { "" }
            $icon.Bottom = if ($pair) { "$($pair.Bottom)" } elseif ($recipe) { "$($recipe.Bottom)" } else { "" }
            $icon.TextColor = if ($pair) { "$($pair.TextColor)" } elseif ($recipe) { "$($recipe.TextColor)" } else { "" }
            $dto.Icon = $icon
            $dto.IconImage = $self.ChosenImage

            $self.Result = $dto
            $self.Close()
        })

        $this.FitToContent($null)
        $null = $this.OpenAs($null)
        return $this.Result
    }

    # Le rapport — la ligne d'état de la fenêtre principale le porte.
    [void] Show([string]$name, [object]$response) {
    }
}
