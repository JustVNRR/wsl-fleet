# ==============================================================================
# LA VUE WPF — LA BASE
# ==============================================================================
# Le jumeau WPF de BaseViewCli : la classe EST une fenêtre — System.Windows.
# Window, par transitivité —, le XAML de la vue (XX.xaml, à côté de son
# XX.xaml.ps1) en devient le Content, et l'appareil porte ce que toutes les
# fenêtres partagent : le dictionnaire du thème, le cadre phosphore, et
# l'ouverture en dialogue de son propriétaire.
#
# Les assemblies WPF (PresentationFramework) sont chargées par l'entrée de la
# fenêtre avant le premier import, comme dans l'appli d'aujourd'hui.
#
# Les poignées d'événements (Add_Click et sœurs) lisent les locales de la
# méthode qui les a posées : ShowDialog tient son cadre ouvert pendant que
# les événements courent, et la portée dynamique les retrouve — la même
# mécanique que les fenêtres d'aujourd'hui. `$this` n'y est PAS lié : on
# pose `$self = $this` avant, et les blocs lisent $self.
using module ..\..\ViewModels\ConfirmViewModel.psm1

class BaseViewWpf : System.Windows.Window {
    # La racine chargée du XAML — c'est elle qui porte les noms.
    hidden [object]$Scope

    # Le résultat qu'une fenêtre pose avant de se fermer : une affectation
    # dans un bloc d'événement reste chez le bloc, jamais dans la méthode —
    # les poignées écrivent donc ICI, et Ask lit après ShowDialog.
    hidden [object]$Result = $null

    # Le look commun des fenêtres — le look choisi et le dossier des assets :
    # posés une fois par l'entrée de la fenêtre (et rafraîchis quand
    # Appearance applique), lus à chaque ouverture — le même rôle que la conf
    # lue au script de la fenêtre d'aujourd'hui. Sans contexte : le chart
    # seul.
    hidden static [object]$Look = $null
    hidden static [string]$Assets = ""

    # La police du visage et les glyphes des boutons — des OBJETS (une famille
    # chargée d'un dossier voyage en objet, jamais en chaîne : mesuré),
    # résolus par le contexte ci-dessous : la fenêtre porte son look elle-même.
    hidden static [object]$UiFont = $null
    hidden static [object]$IconFont = $null
    hidden static [int]$UiSize = 15

    # Le volet : la fenêtre principale s'efface derrière les boîtes et
    # revient quand la dernière se referme. La fenêtre se pose elle-même en
    # s'ouvrant ; le compte dit combien de boîtes sont en l'air — un
    # enfoncement qui s'achève après la dernière fermeture ne doit pas
    # cacher la fenêtre que le retour vient de ramener.
    hidden static [object]$Main = $null
    hidden static [int]$Depth = 0
    # La boîte du dessus : le propriétaire par défaut d'une boîte ouverte par
    # un ViewModel — la naissance tient la fenêtre des packs, pas la
    # principale (sinon la boîte du dessous reste cliquable).
    hidden static [object]$Top = $null

    # Le contexte : le look choisi et le dossier des assets — les POLICES se
    # résolvent ici même : la fenêtre porte son look, l'entrée n'a pas à
    # connaître VT323.
    static [void] SetContext([object]$look, [string]$assetsDir) {
        [BaseViewWpf]::Look = $look
        [BaseViewWpf]::Assets = $assetsDir

        $chosen = ""
        $size = 15
        if ($look) {
            $chosen = "$($look.FontFamily)"
            $size = [int]$look.FontSize
        }
        [BaseViewWpf]::UiSize = $size
        [BaseViewWpf]::UiFont = [BaseViewWpf]::ChosenFace($assetsDir, $chosen)
        [BaseViewWpf]::IconFont = [BaseViewWpf]::IconFace($assetsDir)
    }

    # Les dossiers qui portent une face : ceux qui tiennent un fichier de
    # police LÀ, maintenant — le système de fichiers est la vérité (le cache
    # de polices, lui, sert des fichiers disparus et ignore les ajoutés).
    hidden static [string[]] FontFolders([string]$assetsDir) {
        $fontHome = Join-Path $assetsDir "fonts"
        if (-not (Test-Path $fontHome)) { return @() }
        return @(Get-ChildItem $fontHome -Directory | Where-Object {
            @(Get-ChildItem $_.FullName -File | Where-Object { $_.Extension -in ".ttf", ".otf" }).Count -gt 0
        } | ForEach-Object { $_.FullName })
    }

    # Une famille servie par le cache peut avoir perdu son fichier : un
    # glyphe demandé dit si elle dessine encore.
    hidden static [bool] FontUsable([object]$face) {
        if (-not $face) { return $false }
        try {
            $typeface = New-Object Windows.Media.Typeface($face,
                [Windows.FontStyles]::Normal, [Windows.FontWeights]::Normal, [Windows.FontStretches]::Normal)
            $ft = New-Object Windows.Media.FormattedText("x",
                [Globalization.CultureInfo]::InvariantCulture, [Windows.FlowDirection]::LeftToRight,
                $typeface, [double]12, [Windows.Media.Brushes]::Black, [double]1)
            $null = $ft.Width
            return $true
        } catch {
            return $false
        }
    }

    # La famille choisie, en objet : les dossiers d'abord, la machine
    # ensuite. Rien quand elle ne se trouve pas — le chart prendra sa police
    # par défaut.
    hidden static [object] ChosenFace([string]$assetsDir, [string]$name) {
        if (-not $name) { return $null }
        foreach ($dir in [BaseViewWpf]::FontFolders($assetsDir)) {
            try {
                $uri = [Uri]("file:///" + ($dir -replace '\\', '/') + "/")
                foreach ($candidate in [Windows.Media.Fonts]::GetFontFamilies($uri)) {
                    $faceName = "$($candidate.FamilyNames.Values | Select-Object -First 1)"
                    if ($faceName -eq $name -and ([BaseViewWpf]::FontUsable($candidate))) { return $candidate }
                }
            } catch { }
        }
        $system = @([Windows.Media.Fonts]::SystemFontFamilies | ForEach-Object { "$($_.Source)" })
        if ($system -contains $name) {
            $candidate = [Windows.Media.FontFamily]::new($name)
            if ([BaseViewWpf]::FontUsable($candidate)) { return $candidate }
        }
        return $null
    }

    # Les glyphes des boutons — Font Awesome, dans les dossiers.
    hidden static [object] IconFace([string]$assetsDir) {
        foreach ($dir in [BaseViewWpf]::FontFolders($assetsDir)) {
            try {
                $uri = [Uri]("file:///" + ($dir -replace '\\', '/') + "/")
                foreach ($family in [Windows.Media.Fonts]::GetFontFamilies($uri)) {
                    if ("$($family.Source)" -like "*Font Awesome*" -and ([BaseViewWpf]::FontUsable($family))) { return $family }
                }
            } catch { }
        }
        return $null
    }

    BaseViewWpf() {
        $this.SetResourceReference([System.Windows.Window]::BackgroundProperty, "AppBackgroundBrush")
        $this.SetResourceReference([System.Windows.Window]::ForegroundProperty, "AppForegroundBrush")
        $this.FontFamily = "Segoe UI"
        $this.FontSize = 13
    }

    # Le dictionnaire du look en cours — le contexte rempli par l'entrée.
    [void] WearDefault() {
        $set = if ([BaseViewWpf]::Look) { "$([BaseViewWpf]::Look.ColorTheme)" } else { "" }
        $variant = if ([BaseViewWpf]::Look) { "$([BaseViewWpf]::Look.Variant)" } else { "Dark" }
        $this.WearTheme([BaseViewWpf]::Assets, $set, $variant)
    }

    # Le XAML de la vue, en Content. Le chemin arrive entier — la vue le
    # calcule depuis SON dossier ($PSScriptRoot d'une méthode de classe = le
    # dossier du module qui l'a définie, mesuré).
    [void] Load([string]$path) {
        $loaded = [Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new([xml][System.IO.File]::ReadAllText($path)))
        $this.Content = $loaded
        $this.Scope = $loaded
    }

    # Les contrôles par leur nom — sur la racine chargée.
    [object] Find([string]$name) {
        return $this.Scope.FindName($name)
    }

    # Un "#RRGGBB" (trois chiffres acceptés), un "rgb(...)", ou rien — un
    # pinceau pour peindre un aperçu. Ce qui ne se lit pas rend $null : la
    # fenêtre qui peint a sa couleur de repli.
    hidden [object] Brush([string]$hex) {
        if ($hex -match '^#([0-9a-fA-F]{3})$') {
            $v = $Matches[1]
            $hex = "#$($v[0])$($v[0])$($v[1])$($v[1])$($v[2])$($v[2])"
        }
        if ($hex -match '^#([0-9a-fA-F]{6})$') {
            $h = $Matches[1]
            return [Windows.Media.SolidColorBrush]::new([Windows.Media.Color]::FromRgb(
                [Convert]::ToInt32($h.Substring(0, 2), 16),
                [Convert]::ToInt32($h.Substring(2, 2), 16),
                [Convert]::ToInt32($h.Substring(4, 2), 16)))
        }
        if ($hex -match '^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)') {
            return [Windows.Media.SolidColorBrush]::new([Windows.Media.Color]::FromRgb(
                [int]$Matches[1], [int]$Matches[2], [int]$Matches[3]))
        }
        return $null
    }

    # Le dictionnaire du thème : le chart de l'appareil (theme.xaml, à côté de
    # ce fichier), puis la version choisie par-dessus — assets\themes\<nom>.xaml,
    # le bloc Dark ou Light pris dedans. Un nom devenu invalide laisse le
    # chart debout. Rappelé en direct : la copie déjà fusionnée est REMPLACÉE,
    # pas empilée.
    [void] WearTheme([string]$assetsDir, [string]$colourSet, [string]$variant) {
        $chartPath = Join-Path $PSScriptRoot "theme.xaml"
        $dictionary = [Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new([xml][System.IO.File]::ReadAllText($chartPath)))
        if ($colourSet) {
            $setPath = Join-Path $assetsDir ("themes\" + [IO.Path]::GetFileNameWithoutExtension($colourSet) + ".xaml")
            if (Test-Path $setPath) {
                try {
                    $set = [Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new([xml][System.IO.File]::ReadAllText($setPath)))
                    foreach ($name in @($variant, "Dark")) {
                        if ($name -and $set.Contains($name) -and $set[$name] -is [System.Windows.ResourceDictionary]) { $set = $set[$name]; break }
                    }
                    foreach ($key in @($set.Keys)) {
                        if ($dictionary.Contains($key)) { $dictionary[$key] = $set[$key] }
                    }
                } catch { }
            }
        }
        # Les glyphes des boutons — la famille en OBJET, dans le dictionnaire
        # même : un DynamicResource la résout partout, gabarits compris.
        if ([BaseViewWpf]::IconFont) { $dictionary["IconFace"] = [BaseViewWpf]::IconFont }

        if ($this.Resources.MergedDictionaries.Count -gt 0) {
            $this.Resources.MergedDictionaries[0] = $dictionary
        } else {
            $this.Resources.MergedDictionaries.Add($dictionary)
        }
    }

    # Le thème choisi porte-t-il la version claire — le chart quand le nom est
    # vide. Un fichier illisible ne ment pas : pas de claire, rien à proposer.
    [bool] ThemeHasLight([string]$assetsDir, [string]$colourSet) {
        $path = Join-Path $PSScriptRoot "theme.xaml"
        if ($colourSet) {
            $candidate = Join-Path $assetsDir ("themes\" + [IO.Path]::GetFileNameWithoutExtension($colourSet) + ".xaml")
            if (Test-Path $candidate) { $path = $candidate }
        }
        try {
            $dictionary = [Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new([xml][System.IO.File]::ReadAllText($path)))
            return [bool]$dictionary.Contains("Light")
        } catch {
            return $false
        }
    }

    # Le cadre phosphore : aucune chrome, une fenêtre transparente, le cadre
    # dessiné ici — chaque fenêtre le porte sans XAML pour lui, et se glisse
    # par le fond. C'est ici que vit la première moitié du volet — la boîte
    # se pose, puis la fenêtre principale s'enfonce ; le retour vit dans
    # OpenAs.
    [void] Dress([object]$uiFont, [int]$fontSize) {
        # Sans police donnée, celle du contexte : l'entrée l'a posée — la vue
        # n'a pas à la connaître. Une locale neuve pour la reprendre : une
        # locale qui porterait le nom d'une propriété (statique comprise)
        # est refusée au parse (mesuré — MissingTypeInStaticPropertyAssignment).
        $face = $uiFont
        $size = $fontSize
        if (-not $face) {
            $face = [BaseViewWpf]::UiFont
            $size = [BaseViewWpf]::UiSize
        }
        # La taille s'affiche à sa valeur — le texte comme les icônes : rien
        # ne se zoome, la fenêtre suit son contenu (SizeToContent).
        if ($face) { $this.FontFamily = $face }
        if ($size -gt 0) { $this.FontSize = $size }

        if ($this.Tag -ne 'framed') {
            $this.Tag = 'framed'
            $this.WindowStyle = [System.Windows.WindowStyle]::None
            $this.AllowsTransparency = $true
            $this.Background = [System.Windows.Media.Brushes]::Transparent

            $content = $this.Content
            $this.Content = $null
            $border = New-Object System.Windows.Controls.Border
            # Les trois couleurs du cadre viennent du chart de la fenêtre —
            # un fichier de jeu recolore le cadre comme le reste.
            $border.BorderBrush = $this.FindResource("AppFrameBrush")
            $border.BorderThickness = [System.Windows.Thickness]::new(1)
            $border.CornerRadius = [System.Windows.CornerRadius]::new(6)
            $border.Background = $this.FindResource("AppBackgroundBrush")
            $border.Margin = [System.Windows.Thickness]::new(14)
            $effect = New-Object System.Windows.Media.Effects.DropShadowEffect
            $effect.Color = $this.FindResource("AppGlowColor")
            $effect.BlurRadius = 10
            $effect.ShadowDepth = 0
            $effect.Opacity = 0.30
            $border.Effect = $effect
            $border.Child = $content
            $border.Tag = "wsl-frame"
            $this.Content = $border

            $this.Add_MouseLeftButtonDown({
                param($source, $e)
                $node = $e.OriginalSource
                try {
                    while ($node -and $node -ne $source) {
                        if ($node -is [System.Windows.Controls.Primitives.ButtonBase] -or
                            $node -is [System.Windows.Controls.TextBox] -or
                            $node -is [System.Windows.Controls.Primitives.ScrollBar] -or
                            $node -is [System.Windows.Controls.ComboBox]) { return }
                        $node = [System.Windows.Media.VisualTreeHelper]::GetParent($node)
                    }
                    $source.DragMove()
                } catch { }
            })

            # L'arrivée : un court fondu, attendu sur ContentRendered — après
            # la première passe de dessin, jamais sur Loaded (commencé avant,
            # le fondu luttait contre la première pose — la plus lourde). Et
            # le volet : la boîte se pose AU-DESSUS, et une fois dessinée la
            # fenêtre principale s'efface derrière — l'écran n'est jamais
            # vide pendant que la boîte se construit, et le cadre modal de
            # ShowDialog rend le parent sourd dès le premier instant. La
            # fenêtre suit un rien plus lentement et se cache au bout — sauf
            # si la boîte est déjà repartie (une fermeture éclair) : le
            # retour d'OpenAs a pris la main, son fondu a REMPLACÉ
            # l'enfoncement (le compte est la ceinture).
            $this.Opacity = 0
            $this.Add_ContentRendered({
                param($source, $e)
                $fade = [System.Windows.Media.Animation.DoubleAnimation]::new(0, 1, [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(180)))
                $fade.EasingFunction = [System.Windows.Media.Animation.QuadraticEase]::new()
                $fade.EasingFunction.EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseOut
                $source.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $fade)

                $appWindow = [BaseViewWpf]::Main
                if ($appWindow -and $appWindow -ne $source -and [BaseViewWpf]::Depth -le 1) {
                    $sink = [System.Windows.Media.Animation.DoubleAnimation]::new(1, 0, [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(220)))
                    $sink.Add_Completed({
                        param($s, $e)
                        if ([BaseViewWpf]::Depth -gt 0 -and [BaseViewWpf]::Main) { [BaseViewWpf]::Main.Hide() }
                    })
                    $appWindow.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $sink)
                }
            })
        }

        # Le cadre relu à chaque passage — le chart a pu changer sous lui, et
        # un pinceau lu au premier passage tiendrait l'ancien.
        $frame = $this.Content
        if ($frame -is [System.Windows.Controls.Border] -and "$($frame.Tag)" -eq "wsl-frame") {
            $frame.BorderBrush = $this.FindResource("AppFrameBrush")
            $frame.Background = $this.FindResource("AppBackgroundBrush")
            if ($frame.Effect -is [System.Windows.Media.Effects.DropShadowEffect]) {
                $effect = New-Object System.Windows.Media.Effects.DropShadowEffect
                $effect.Color = $this.FindResource("AppGlowColor")
                $effect.BlurRadius = 10
                $effect.ShadowDepth = 0
                $effect.Opacity = 0.30
                $frame.Effect = $effect
            }
        }
    }

    # La fenêtre suit son contenu (SizeToContent) — ici, seule la borne à
    # l'écran reste : la hauteur plafonnée à l'écran où elle vit.
    # -ScreenOf : l'écran de la fenêtre par-dessus ; sans lui, rien.
    [void] FitToContent([object]$screenOf) {
        $area = if ($screenOf) { $this.GetScreenWorkingArea($screenOf) } else { $null }
        if ($area) { $this.MaxHeight = [Math]::Floor($area.Height) }
    }

    # L'écran où vit la fenêtre donnée, dans SES unités — une fenêtre n'a pas
    # de handle avant d'être montrée, et SystemParameters ne connaît que la
    # primaire : l'ancre se passe. Une lecture ratée rend $null (pas de
    # borne), pas une erreur.
    hidden [object] GetScreenWorkingArea([object]$window) {
        try {
            $handle = [System.Windows.Interop.WindowInteropHelper]::new($window).Handle
            if (-not $handle) { return $null }
            $area = [System.Windows.Forms.Screen]::FromHandle($handle).WorkingArea
            $dpi = [System.Windows.Media.VisualTreeHelper]::GetDpi($window)
            return [PSCustomObject]@{ Width = $area.Width / $dpi.DpiScaleX; Height = $area.Height / $dpi.DpiScaleY }
        } catch {
            return $null
        }
    }

    # La plus petite porte, en fenêtre de son propriétaire — un titre, une
    # question (+ la ligne rouge quand il y en a une), Cancel et le CONFIRM.
    # Rend le oui. La fenêtre est une BaseViewWpf nue : le même appareil,
    # le même cadre.
    [bool] ConfirmAs([object]$owner, [string]$title, [string]$question, [string]$danger) {
        $dialog = [BaseViewWpf]::new()
        $vm = [ConfirmViewModel]::new($title, $question, $danger)
        $dialog.Title = "Wsl Fleet"
        $dialog.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
        $dialog.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $dialog.ResizeMode = [System.Windows.ResizeMode]::NoResize
        $dialog.Load((Join-Path $PSScriptRoot "shared\Confirm.xaml"))
        $dialog.WearDefault()
        $dialog.Dress($null, 15)
        $dialog.DataContext = $vm

        # La porte de fermeture — METHODE 1 : le ViewModel dit « j'ai fini »,
        # et la réponse voyage avec (elle vient DE la porte).
        $vm.DemandeFermeture = { param($result) $dialog.Result = $result; $dialog.Close() }

        # The title IS the question: its first line in capitals, the rest
        # (and the danger line) below it.
        $lines = @("$($vm.Question)" -split "`n")
        $dialog.Find("TxtLead").Text = "$($lines[0])".Trim().ToUpperInvariant()

        # The question, one block in two colours: what remains of it, then -
        # when there is one - the danger line under (one more Run in the same
        # TextBlock). A question with nothing left to say hides its block.
        $rest = ""
        if ($lines.Count -gt 1) { $rest = (@($lines[1..($lines.Count - 1)]) -join "`n").Trim() }
        $txtQuestion = $dialog.Find("TxtQuestion")
        $txtQuestion.Inlines.Clear()
        if ($rest) { $txtQuestion.Inlines.Add([System.Windows.Documents.Run]::new($rest)) }
        if ("$($vm.Danger)") {
            if ($rest) {
                $txtQuestion.Inlines.Add([System.Windows.Documents.LineBreak]::new())
                $txtQuestion.Inlines.Add([System.Windows.Documents.LineBreak]::new())
            }
            $dangerRun = [System.Windows.Documents.Run]::new("$($vm.Danger)")
            $dangerRun.Foreground = $dialog.FindResource("AppDangerBrush")
            $txtQuestion.Inlines.Add($dangerRun)
        }
        if (-not $rest -and -not "$($vm.Danger)") { $txtQuestion.Visibility = [System.Windows.Visibility]::Collapsed }

        $dialog.Find("BtnConfirmCancel").Add_Click({ $dialog.Close() })

        $dialog.FitToContent($owner)
        $null = $dialog.OpenAs($owner)
        return [bool]$dialog.Result
    }

    # L'ouverture : un dialogue de son propriétaire — ShowDialog(owner) n'a
    # pas de surcharge (mesuré) : .Owner se pose, ShowDialog() est nu. Sans
    # propriétaire donné, la fenêtre principale — la boîte reste fille de
    # l'appli, l'enfoncement suit (l'autre moitié vit dans Dress, à la
    # première passe de dessin). Le retour : le parent revient SOLIDE — le
    # fondu reprend de là où il en était — et reprend le foyer du clavier,
    # que Hide/Show lui a pris (mesuré : Échap meurt sans lui).
    [object] OpenAs([object]$owner) {
        $parent = $owner
        if (-not $parent -and [BaseViewWpf]::Top -and [BaseViewWpf]::Top.IsVisible -and [BaseViewWpf]::Top -ne $this) { $parent = [BaseViewWpf]::Top }
        if (-not $parent -and [BaseViewWpf]::Main -and [BaseViewWpf]::Main -ne $this) { $parent = [BaseViewWpf]::Main }
        if ($parent) { $this.Owner = $parent }

        [BaseViewWpf]::Depth = [BaseViewWpf]::Depth + 1
        [BaseViewWpf]::Top = $this
        try {
            return $this.ShowDialog()
        } finally {
            [BaseViewWpf]::Depth = [BaseViewWpf]::Depth - 1
            [BaseViewWpf]::Top = [BaseViewWpf]::Main
            # Pas de locale qui porte le nom d'une propriété (statique
            # comprise) : l'affectation nue est refusée au parse (mesuré).
            $appWindow = [BaseViewWpf]::Main
            # Le retour n'est dû qu'à la DERNIÈRE : une boîte imbriquée se
            # referme sans ramener la fenêtre que la boîte du dessus tient
            # encore cachée.
            if ($appWindow -and $appWindow -ne $this -and [BaseViewWpf]::Depth -eq 0) {
                if ($appWindow.Opacity -lt 1) {
                    $appWindow.Show()
                    $fadeIn = [System.Windows.Media.Animation.DoubleAnimation]::new($appWindow.Opacity, 1, [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(130)))
                    $appWindow.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $fadeIn)
                }
                $null = $appWindow.Activate()
                $null = $appWindow.Focus()
            }
        }
    }
}
