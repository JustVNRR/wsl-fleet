# ==============================================================================
# SETAPPEARANCE — LA VUE WPF
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewWpf.psm1
using module ..\..\..\ViewModels\SetAppearanceViewModel.psm1

# Le look d'une instance, la fenêtre : le DataContext est le
# SetAppearanceViewModel — les listes, la tuile, l'image et APPLY se bindent
# en XAML. Ici, ce que WPF demande : le sélecteur d'image (graphisme — le
# ViewModel reçoit le chemin), l'aperçu qui se repeint (les lignes du prompt,
# la palette, l'image choisie), l'Entrée mangée après le sélecteur (mesuré),
# la fermeture sur Done — et le Dto rendu.
class WpfSetAppearanceView : BaseViewWpf {
    # L'Entrée mangée après la fermeture du sélecteur de fichier (mesuré :
    # sans quoi elle retombe sur APPLY et ferme la fenêtre).
    hidden [bool]$EatEnter = $false
    hidden [object]$Vm = $null

    [object] Ask([string]$name, [object]$appearance, [string[]]$fonts, [object[]]$schemes, [object[]]$pairs) {
        $self = $this
        $this.Vm = [SetAppearanceViewModel]::new($name, $appearance, $fonts, $schemes, $pairs)

        $this.Title = "Appearance"
        $this.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
        $this.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $this.ResizeMode = [System.Windows.ResizeMode]::NoResize
        $this.Load((Join-Path $PSScriptRoot "SetAppearance.xaml"))
        $this.WearDefault()
        $this.Dress($null, 15)
        $this.DataContext = $this.Vm

        $this.Vm.add_PropertyChanged({
            param($source, $e)
            if ("$($e.PropertyName)" -eq "Done") { $self.Close() }
            if ("$($e.PropertyName)" -in @("FontIndex", "SchemeIndex")) { $self.PaintPreview() }
            if ("$($e.PropertyName)" -eq "ImagePath") { $self.LoadIconFile("$($self.Vm.ImagePath)") }
        })

        $this.Add_ContentRendered({ $null = $this.Find("TxtIconText").Focus() })

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
            if ($picked -eq $true) { $self.Vm.SetImage($dialog.FileName) }
        })

        $this.Find("BtnLookCancel").Add_Click({ $self.Close() })

        if ("$($this.Vm.ImagePath)") { $this.LoadIconFile("$($this.Vm.ImagePath)") }
        $this.PaintPreview()

        $this.FitToContent($null)
        $null = $this.OpenAs($null)
        return $this.Vm.Result
    }

    # L'aperçu : les lignes du prompt dans la police choisie, peintes des
    # couleurs du schéma, la palette des seize dessous — choisir à l'aveugle
    # était la première critique de cette fenêtre. Le choix se lit au
    # ViewModel, par ses méthodes.
    hidden [void] PaintPreview() {
        $brdPreview = $this.Find("BrdPreview")
        $previewLines = @($this.Find("TxtPreview1"), $this.Find("TxtPreview2"), $this.Find("TxtPreview3"),
            $this.Find("TxtPreview4"), $this.Find("TxtPreview5"), $this.Find("TxtPreview6"))
        $pnlPalette = $this.Find("PnlPalette")
        $slotByIndex = @("Black", "DarkRed", "DarkGreen", "DarkYellow", "DarkBlue", "DarkMagenta", "DarkCyan", "Gray",
            "DarkGray", "Red", "Green", "Yellow", "Blue", "Magenta", "Cyan", "White")

        $fontName = $this.Vm.SelectedFont()
        if ($fontName) {
            # Le constructeur, pas une chaîne : une chaîne qui ne se résout
            # pas se convertit en un « rien n'a bougé » que l'œil ne voit pas.
            $family = [Windows.Media.FontFamily]::new("$fontName")
            foreach ($line in $previewLines) { $line.FontFamily = $family }
        }

        $scheme = $this.Vm.SelectedScheme()
        $bg = $null
        $fg = $null
        if ($scheme) {
            $bg = $this.Brush("$($scheme.Background)")
            $fg = $this.Brush("$($scheme.Foreground)")
        }
        $brdPreview.Background = if ($bg) { $bg } else { $this.Brush("#0C0C0C") }
        foreach ($line in $previewLines) {
            $line.Foreground = if ($fg) { $fg } else { $this.Brush("#33FF66") }
            foreach ($run in @($line.Inlines)) {
                $brush = $null
                if ("$($run.Tag)" -eq 'fg') {
                    $brush = if ($fg) { $fg } else { $this.Brush("#33FF66") }
                } elseif ("$($run.Tag)" -match '^c(\d+)$') {
                    $idx = [int]$Matches[1]
                    if ($scheme -and $idx -lt $slotByIndex.Count) { $brush = $this.Brush("$($scheme.$($slotByIndex[$idx]))") }
                }
                if ($brush) { $run.Foreground = $brush }
            }
        }

        $pnlPalette.Children.Clear()
        if ($scheme) {
            foreach ($slotName in $slotByIndex) {
                $brush = $this.Brush("$($scheme.$slotName)")
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

    # L'image choisie : son aperçu se lit du FICHIER (ses octets), avec les
    # deux options mesurées — OnLoad (le fichier est lu entier et lâché) et
    # IgnoreImageCache (WPF garde les images décodées par URI, et l'aperçu
    # d'une nouvelle sélection du même chemin ne bougerait pas).
    hidden [void] LoadIconFile([string]$path) {
        if (-not $path) { return }
        try {
            $bmp = New-Object Windows.Media.Imaging.BitmapImage
            $bmp.BeginInit()
            $bmp.CreateOptions = [Windows.Media.Imaging.BitmapCreateOptions]::IgnoreImageCache
            $bmp.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            $bmp.UriSource = [Uri]"$path"
            $bmp.EndInit()
            $this.Find("ImgIconPreview").Source = $bmp
        } catch { }
    }
}
