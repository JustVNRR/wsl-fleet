# ==============================================================================
# L'APPARENCE D'UNE INSTANCE — LE VIEWMODEL
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout lui-même ce qu'il
# tire.
using module .\BaseViewModel.psm1
using module ..\Dto\InstanceDto.psm1

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
    hidden [string]$_lead = ""
    hidden [object]$_appearance = $null
    hidden [object]$_recipe = $null
    hidden [object[]]$_pairRows = @()
    hidden [object[]]$_fontRows = @()
    hidden [object[]]$_schemeRows = @()

    hidden [string]$_iconText = ""
    hidden [string]$_iconError = ""
    hidden [int]$_pairIndex = 0
    hidden [int]$_fontIndex = 0
    hidden [int]$_schemeIndex = 0
    hidden [string]$_chosenImage = ""
    hidden [bool]$_noFragment = $false

    [object]$Result = $null
    [System.Windows.Input.ICommand]$ApplyCommand

    SetAppearanceViewModel([string]$name, [object]$appearance, [string[]]$fonts, [object[]]$schemes, [object[]]$pairs) {
        $this._name = "$name"
        $this._lead = "$name's appearance."
        $this._appearance = $appearance
        $this._recipe = $appearance.Icon
        $this._noFragment = (-not [bool]$appearance.HasFragment)

        # La tuile : les lettres, et les paires offertes — la paire en place
        # marquée. Chaque paire est montrée avec les lettres en main : deux
        # codes hexadécimaux ne disent rien à l'œil.
        $this._iconText = "$($this._recipe.Text)"
        $pairRows = @()
        foreach ($pair in @($pairs)) {
            $here = if ($this._recipe -and $pair.Top -eq $this._recipe.Top -and $pair.Bottom -eq $this._recipe.Bottom) { "  (current)" } else { "" }
            $pairRows += [PSCustomObject]@{ Pair = $pair; Label = "$($pair.Name)$here"; Current = [bool]$here }
        }
        $this._pairRows = @($pairRows)

        # La police : la liste reçue, celle en place marquée — et prépendue
        # quand elle n'y est pas : une liste qui l'ignore ment sur ce que
        # l'instance porte.
        $fontRows = @()
        $fontNames = @()
        foreach ($font in @($fonts)) { $fontNames += "$font" }
        if ($fontNames -notcontains "$($appearance.Font)") { $fontNames = @("$($appearance.Font)") + $fontNames }
        foreach ($fontName in $fontNames) {
            $here = if ($fontName -eq "$($appearance.Font)") { "  (current)" } else { "" }
            $fontRows += [PSCustomObject]@{ Name = $fontName; Label = "$fontName$here"; Current = [bool]$here }
        }
        $this._fontRows = @($fontRows)

        $schemeRows = @()
        foreach ($scheme in @($schemes | Sort-Object Name)) {
            $here = if ($scheme.Name -eq "$($appearance.ColourScheme)") { "  (current)" } else { "" }
            $schemeRows += [PSCustomObject]@{ Scheme = $scheme; Label = "$($scheme.Name)$here"; Current = [bool]$here }
        }
        $this._schemeRows = @($schemeRows)

        # L'image en place — le siège de l'icône, quand une y est posée.
        if ("$($appearance.IconPath)" -and (Test-Path "$($appearance.IconPath)")) {
            $this._chosenImage = "$($appearance.IconPath)"
        }

        $this.AddProperty("Lead", { return $this._lead }, { param($value) })
        $this.AddProperty("IconText", { return $this._iconText }, {
            param($value)
            if ($this._iconText -ne "$value") {
                $this._iconText = "$value"
                $this.OnPropertyChanged("IconText")
                $this._chosenImage = ""
                $this.OnPropertyChanged("ImagePath")
                $this.ValidateIcon()
            }
        })
        $this.AddProperty("IconError", { return $this._iconError }, {
            param($value)
            if ($this._iconError -ne "$value") { $this._iconError = "$value"; $this.OnPropertyChanged("IconError") }
        })
        $this.AddProperty("Pairs", { return $this._pairRows }, { param($value) })
        $this.AddProperty("PairIndex", { return $this._pairIndex }, {
            param($value)
            if ($this._pairIndex -ne [int]$value) {
                $this._pairIndex = [int]$value
                $this.OnPropertyChanged("PairIndex")
                $this._chosenImage = ""
                $this.OnPropertyChanged("ImagePath")
            }
        })
        $this.AddProperty("Fonts", { return $this._fontRows }, { param($value) })
        $this.AddProperty("FontIndex", { return $this._fontIndex }, {
            param($value)
            if ($this._fontIndex -ne [int]$value) { $this._fontIndex = [int]$value; $this.OnPropertyChanged("FontIndex") }
        })
        $this.AddProperty("Schemes", { return $this._schemeRows }, { param($value) })
        $this.AddProperty("SchemeIndex", { return $this._schemeIndex }, {
            param($value)
            if ($this._schemeIndex -ne [int]$value) { $this._schemeIndex = [int]$value; $this.OnPropertyChanged("SchemeIndex") }
        })
        $this.AddProperty("ImagePath", { return $this._chosenImage }, { param($value) })
        $this.AddProperty("NoFragment", { return $this._noFragment }, { param($value) })

        $this.ApplyCommand = $this.NewCommand({ param($vm) $vm.Apply() }, { param($vm) $vm.CanApply() })
        $this.ValidateIcon()
    }

    # La règle des lettres, dite sous la boîte : jusqu'à trois, lettres ou
    # chiffres.
    [void] ValidateIcon() {
        $ok = ("$($this._iconText)" -match '^[A-Za-z0-9]{1,3}$')
        $this._iconError = if ($ok) { "" } else { "One to three letters or digits." }
        $this.OnPropertyChanged("IconError")
        $this.ApplyCommand.RaiseCanExecuteChanged()
    }

    [bool] CanApply() {
        return ("$($this._iconText)" -match '^[A-Za-z0-9]{1,3}$')
    }

    # Le fichier choisi par la vue (le sélecteur est chez elle — graphisme).
    [void] SetImage([string]$path) {
        $this._chosenImage = "$path"
        $this.OnPropertyChanged("ImagePath")
    }

    # Ce que l'aperçu peint — lu par la vue, par méthode.
    [string] SelectedFont() {
        if ($this._fontRows.Count -eq 0) { return "$($this._appearance.Font)" }
        $at = [Math]::Max(0, [Math]::Min($this._fontIndex, $this._fontRows.Count - 1))
        return "$($this._fontRows[$at].Name)"
    }

    [object] SelectedScheme() {
        if ($this._schemeRows.Count -eq 0) { return $null }
        $at = [Math]::Max(0, [Math]::Min($this._schemeIndex, $this._schemeRows.Count - 1))
        return $this._schemeRows[$at].Scheme
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
        $icon.Text = "$($this._iconText)".ToUpper()
        $pair = $null
        if ($this._pairRows.Count -gt 0) {
            $at = [Math]::Max(0, [Math]::Min($this._pairIndex, $this._pairRows.Count - 1))
            $pair = $this._pairRows[$at].Pair
        }
        $icon.Top = if ($pair) { "$($pair.Top)" } elseif ($this._recipe) { "$($this._recipe.Top)" } else { "" }
        $icon.Bottom = if ($pair) { "$($pair.Bottom)" } elseif ($this._recipe) { "$($this._recipe.Bottom)" } else { "" }
        $icon.TextColor = if ($pair) { "$($pair.TextColor)" } elseif ($this._recipe) { "$($this._recipe.TextColor)" } else { "" }
        $dto.Icon = $icon
        $dto.IconImage = $this._chosenImage

        $this.Result = $dto
        $this.OnPropertyChanged("Done")
    }
}
