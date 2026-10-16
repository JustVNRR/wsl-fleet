# ==============================================================================
# L'APPARENCE D'UNE INSTANCE — LE VIEWMODEL
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout lui-même ce qu'il
# tire.
using module .\BaseViewModel.psm1
using module ..\Dto\InstanceDto.psm1

# Les lignes des listes de la tuile : le libellé que la liste montre, la
# paire ou le schéma gardés derrière. De VRAIES classes — WPF ne lit que les
# vraies propriétés .NET : un PSCustomObject s'afficherait brut (même mur
# que les Réglages, mesuré sur sa machine).
class LookPairRow {
    [object]$Pair = $null
    [string]$Label = ""
    [bool]$Current = $false
}

class LookFontRow {
    [string]$Name = ""
    [string]$Label = ""
    [bool]$Current = $false
}

class LookSchemeRow {
    [object]$Scheme = $null
    [string]$Label = ""
    [bool]$Current = $false
}

# Le look d'une instance : les lettres et les paires de la tuile, une image à
# soi, la police et le schéma de couleurs. Rien ne s'applique ici : APPLY
# rend le SetAppearanceDto, le service l'applique.
#
# Une simplification assumée (la même qu'au cli) : la tuile ne se dessine plus
# à chaque tour — une vue ne lance pas make-icon. L'aperçu de la tuile montre
# l'image CHOISIE ; la recette se dessinera une fois, à l'application.
#
# L'image prend le siège et le dessin reste derrière : une retouche des
# lettres ou des paires reprend le siège (l'image s'efface).
class SetAppearanceViewModel : BaseViewModel {
    hidden [string]$_name = ""
    hidden [object]$_appearance = $null
    hidden [object]$_recipe = $null

    # L'état bindable : de VRAIES propriétés de classe — WPF ne lit que
    # celles-là. Les listes montrent leurs LIBELLÉS, en chaînes (WPF les
    # affiche sûrement), les lignes gardent le reste.
    [string]$Lead = ""
    [object[]]$Pairs = @()
    [string[]]$PairLabels = @()
    [object[]]$Fonts = @()
    [string[]]$FontLabels = @()
    [object[]]$Schemes = @()
    [string[]]$SchemeLabels = @()
    [string]$IconText = ""
    [string]$IconError = ""
    [int]$PairIndex = 0
    [int]$FontIndex = 0
    [int]$SchemeIndex = 0
    [string]$ImagePath = ""
    [bool]$NoFragment = $false

    [object]$Result = $null
    [System.Windows.Input.ICommand]$ApplyCommand

    SetAppearanceViewModel([string]$name, [object]$appearance, [string[]]$fonts, [object[]]$schemes, [object[]]$pairs) {
        $this._name = "$name"
        $this.Lead = ("$name's appearance.").ToUpperInvariant()
        $this._appearance = $appearance
        $this._recipe = $appearance.Icon
        $this.NoFragment = (-not [bool]$appearance.HasFragment)

        # La tuile : les lettres, et les paires offertes — la paire en place
        # marquée. Chaque paire est montrée avec les lettres en main : deux
        # codes hexadécimaux ne disent rien à l'œil.
        $this.IconText = "$($this._recipe.Text)"
        $pairRows = @()
        foreach ($pair in @($pairs)) {
            $here = if ($this._recipe -and $pair.Top -eq $this._recipe.Top -and $pair.Bottom -eq $this._recipe.Bottom) { "  (current)" } else { "" }
            $pairRows += [LookPairRow]@{ Pair = $pair; Label = "$($pair.Name)$here"; Current = [bool]$here }
        }
        $this.Pairs = @($pairRows)
        $this.PairLabels = @($pairRows | ForEach-Object { "$($_.Label)" })
        # La sélection pointe la ligne EN PLACE — l'écran dit la vérité, et
        # APPLY sans retouche n'écrit pas autre chose (vécu : indices restés
        # à 0, APPLY changeait police et schéma tout seuls).
        if ($this._recipe) {
            for ($i = 0; $i -lt $this.Pairs.Count; $i++) {
                $pair = $this.Pairs[$i].Pair
                if ($pair.Top -eq $this._recipe.Top -and $pair.Bottom -eq $this._recipe.Bottom) { $this.PairIndex = $i; break }
            }
        }

        # La police : la liste reçue, celle en place marquée — et prépendue
        # quand elle n'y est pas : une liste qui l'ignore ment sur ce que
        # l'instance porte.
        $fontRows = @()
        $fontNames = @()
        foreach ($font in @($fonts)) { $fontNames += "$font" }
        if ($fontNames -notcontains "$($appearance.Font)") { $fontNames = @("$($appearance.Font)") + $fontNames }
        foreach ($fontName in $fontNames) {
            $here = if ($fontName -eq "$($appearance.Font)") { "  (current)" } else { "" }
            $fontRows += [LookFontRow]@{ Name = $fontName; Label = "$fontName$here"; Current = [bool]$here }
        }
        $this.Fonts = @($fontRows)
        $this.FontLabels = @($fontRows | ForEach-Object { "$($_.Label)" })
        for ($i = 0; $i -lt $this.Fonts.Count; $i++) {
            if ("$($this.Fonts[$i].Name)" -eq "$($appearance.Font)") { $this.FontIndex = $i; break }
        }

        $schemeRows = @()
        foreach ($scheme in @($schemes | Sort-Object Name)) {
            $here = if ($scheme.Name -eq "$($appearance.ColourScheme)") { "  (current)" } else { "" }
            $schemeRows += [LookSchemeRow]@{ Scheme = $scheme; Label = "$($scheme.Name)$here"; Current = [bool]$here }
        }
        $this.Schemes = @($schemeRows)
        $this.SchemeLabels = @($schemeRows | ForEach-Object { "$($_.Label)" })
        for ($i = 0; $i -lt $this.Schemes.Count; $i++) {
            if ("$($this.Schemes[$i].Scheme.Name)" -eq "$($appearance.ColourScheme)") { $this.SchemeIndex = $i; break }
        }

        # L'image en place — le siège de l'icône, quand une y est posée.
        if ("$($appearance.IconPath)" -and (Test-Path "$($appearance.IconPath)")) {
            $this.ImagePath = "$($appearance.IconPath)"
        }

        $this.ApplyCommand = $this.NewCommand({ param($vm) $vm.Apply() }, { param($vm) $vm.CanApply() })
        $this.ValidateIcon()
    }

    # Les liens XAML sont à sens unique : la vue relaie chaque saisie ici —
    # la garde, l'effet sur le siège de l'image et la validation vivent d'un
    # seul côté.
    [void] SetIconText([string]$value) {
        if ($this.IconText -cne "$value") {
            $this.IconText = "$value"
            $this.OnPropertyChanged("IconText")
            $this.ImagePath = ""
            $this.OnPropertyChanged("ImagePath")
            $this.ValidateIcon()
        }
    }

    [void] SetPairIndex([int]$value) {
        if ($this.PairIndex -ne $value) {
            $this.PairIndex = $value
            $this.OnPropertyChanged("PairIndex")
            $this.ImagePath = ""
            $this.OnPropertyChanged("ImagePath")
        }
    }

    [void] SetFontIndex([int]$value) {
        if ($this.FontIndex -ne $value) {
            $this.FontIndex = $value
            $this.OnPropertyChanged("FontIndex")
        }
    }

    [void] SetSchemeIndex([int]$value) {
        if ($this.SchemeIndex -ne $value) {
            $this.SchemeIndex = $value
            $this.OnPropertyChanged("SchemeIndex")
        }
    }

    # La règle des lettres, dite sous la boîte : jusqu'à trois, lettres ou
    # chiffres.
    [void] ValidateIcon() {
        $ok = ("$($this.IconText)" -match '^[A-Za-z0-9]{1,3}$')
        $this.IconError = if ($ok) { "" } else { "One to three letters or digits." }
        $this.OnPropertyChanged("IconError")
        $this.ApplyCommand.RaiseCanExecuteChanged()
    }

    [bool] CanApply() {
        return ("$($this.IconText)" -match '^[A-Za-z0-9]{1,3}$')
    }

    # Le fichier choisi par la vue (le sélecteur est chez elle — graphisme).
    [void] SetImage([string]$path) {
        $this.ImagePath = "$path"
        $this.OnPropertyChanged("ImagePath")
    }

    # Ce que la tuile montre en direct : la paire choisie (la recette en
    # place sinon), les lettres en main — la vue la peint, make-icon la
    # dessinera pareil.
    [object] PreviewIcon() {
        $pair = $null
        if ($this.Pairs.Count -gt 0) {
            $at = [Math]::Max(0, [Math]::Min($this.PairIndex, $this.Pairs.Count - 1))
            $pair = $this.Pairs[$at].Pair
        }
        return [PSCustomObject]@{
            Text      = "$($this.IconText)".ToUpper()
            Top       = if ($pair) { "$($pair.Top)" } elseif ($this._recipe) { "$($this._recipe.Top)" } else { "" }
            Bottom    = if ($pair) { "$($pair.Bottom)" } elseif ($this._recipe) { "$($this._recipe.Bottom)" } else { "" }
            TextColor = if ($pair) { "$($pair.TextColor)" } elseif ($this._recipe) { "$($this._recipe.TextColor)" } else { "" }
        }
    }

    # Ce que l'aperçu peint — lu par la vue, par méthode.
    [string] SelectedFont() {
        if ($this.Fonts.Count -eq 0) { return "$($this._appearance.Font)" }
        $at = [Math]::Max(0, [Math]::Min($this.FontIndex, $this.Fonts.Count - 1))
        return "$($this.Fonts[$at].Name)"
    }

    [object] SelectedScheme() {
        if ($this.Schemes.Count -eq 0) { return $null }
        $at = [Math]::Max(0, [Math]::Min($this.SchemeIndex, $this.Schemes.Count - 1))
        return $this.Schemes[$at].Scheme
    }

    # APPLY : les lettres sont la seule règle de la tuile ; les listes
    # répondent d'elles-mêmes. L'image choisie prend le siège ; le dessin,
    # lui, reste derrière.
    [void] Apply() {
        if (-not $this.CanApply()) { return }
        $dto = [SetAppearanceDto]::new()
        $dto.InstanceName = $this._name
        $dto.Font = $this.SelectedFont()
        $scheme = $this.SelectedScheme()
        $dto.ColourScheme = if ($scheme) { "$($scheme.Name)" } else { "$($this._appearance.ColourScheme)" }

        $icon = [WslIconDto]::new()
        $icon.Text = "$($this.IconText)".ToUpper()
        $pair = $null
        if ($this.Pairs.Count -gt 0) {
            $at = [Math]::Max(0, [Math]::Min($this.PairIndex, $this.Pairs.Count - 1))
            $pair = $this.Pairs[$at].Pair
        }
        $icon.Top = if ($pair) { "$($pair.Top)" } elseif ($this._recipe) { "$($this._recipe.Top)" } else { "" }
        $icon.Bottom = if ($pair) { "$($pair.Bottom)" } elseif ($this._recipe) { "$($this._recipe.Bottom)" } else { "" }
        $icon.TextColor = if ($pair) { "$($pair.TextColor)" } elseif ($this._recipe) { "$($this._recipe.TextColor)" } else { "" }
        $dto.Icon = $icon
        $dto.IconImage = $this.ImagePath

        $this.Result = $dto
        $this.RequestClose()
    }
}
