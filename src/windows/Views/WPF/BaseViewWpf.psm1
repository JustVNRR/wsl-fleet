using module ..\..\ViewModels\ConfirmViewModel.psm1

class BaseViewWpf : System.Windows.Window {
    hidden [object]$Scope

    hidden [object]$Result = $null

    hidden static [object]$Look = $null
    hidden static [string]$Assets = ""

    hidden static [object]$UiFont = $null
    hidden static [object]$IconFont = $null
    hidden static [int]$UiSize = 15

    hidden static [object]$Main = $null
    hidden static [int]$Depth = 0
    hidden static [object]$Top = $null

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

    hidden static [string[]] FontFolders([string]$assetsDir) {
        $fontHome = Join-Path $assetsDir "fonts"
        if (-not (Test-Path $fontHome)) { return @() }
        return @(Get-ChildItem $fontHome -Directory | Where-Object {
            @(Get-ChildItem $_.FullName -File | Where-Object { $_.Extension -in ".ttf", ".otf" }).Count -gt 0
        } | ForEach-Object { $_.FullName })
    }

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

    [void] WearDefault() {
        $set = if ([BaseViewWpf]::Look) { "$([BaseViewWpf]::Look.ColorTheme)" } else { "" }
        $variant = if ([BaseViewWpf]::Look) { "$([BaseViewWpf]::Look.Variant)" } else { "Dark" }
        $this.WearTheme([BaseViewWpf]::Assets, $set, $variant)
    }

    [void] Load([string]$path) {
        $loaded = [Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new([xml][System.IO.File]::ReadAllText($path)))
        $this.Content = $loaded
        $this.Scope = $loaded
    }

    [object] Find([string]$name) {
        return $this.Scope.FindName($name)
    }

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
        if ([BaseViewWpf]::IconFont) { $dictionary["IconFace"] = [BaseViewWpf]::IconFont }

        if ($this.Resources.MergedDictionaries.Count -gt 0) {
            $this.Resources.MergedDictionaries[0] = $dictionary
        } else {
            $this.Resources.MergedDictionaries.Add($dictionary)
        }
    }

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

    [void] Dress([object]$uiFont, [int]$fontSize) {
        $face = $uiFont
        $size = $fontSize
        if (-not $face) {
            $face = [BaseViewWpf]::UiFont
            $size = [BaseViewWpf]::UiSize
        }
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

    [void] FitToContent([object]$screenOf) {
        $area = if ($screenOf) { $this.GetScreenWorkingArea($screenOf) } else { $null }
        if ($area) { $this.MaxHeight = [Math]::Floor($area.Height) }
    }

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

        $vm.DemandeFermeture = { param($result) $dialog.Result = $result; $dialog.Close() }

        $lines = @("$($vm.Question)" -split "`n")
        $dialog.Find("TxtLead").Text = "$($lines[0])".Trim().ToUpperInvariant()

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
            $appWindow = [BaseViewWpf]::Main
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
