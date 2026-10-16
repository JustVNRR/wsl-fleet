using module .\BaseViewModel.psm1
using module ..\Dtos\InstanceDto.psm1

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

class SetAppearanceViewModel : BaseViewModel {
    hidden [string]$_name = ""
    hidden [object]$_appearance = $null
    hidden [object]$_recipe = $null

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

        $this.IconText = "$($this._recipe.Text)"
        $pairRows = @()
        foreach ($pair in @($pairs)) {
            $here = if ($this._recipe -and $pair.Top -eq $this._recipe.Top -and $pair.Bottom -eq $this._recipe.Bottom) { "  (current)" } else { "" }
            $pairRows += [LookPairRow]@{ Pair = $pair; Label = "$($pair.Name)$here"; Current = [bool]$here }
        }
        $this.Pairs = @($pairRows)
        $this.PairLabels = @($pairRows | ForEach-Object { "$($_.Label)" })
        if ($this._recipe) {
            for ($i = 0; $i -lt $this.Pairs.Count; $i++) {
                $pair = $this.Pairs[$i].Pair
                if ($pair.Top -eq $this._recipe.Top -and $pair.Bottom -eq $this._recipe.Bottom) { $this.PairIndex = $i; break }
            }
        }

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

        if ("$($appearance.IconPath)" -and (Test-Path "$($appearance.IconPath)")) {
            $this.ImagePath = "$($appearance.IconPath)"
        }

        $this.ApplyCommand = $this.NewCommand({ param($vm) $vm.Apply() }, { param($vm) $vm.CanApply() })
        $this.ValidateIcon()
    }

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

    [void] ValidateIcon() {
        $ok = ("$($this.IconText)" -match '^[A-Za-z0-9]{1,3}$')
        $this.IconError = if ($ok) { "" } else { "One to three letters or digits." }
        $this.OnPropertyChanged("IconError")
        $this.ApplyCommand.RaiseCanExecuteChanged()
    }

    [bool] CanApply() {
        return ("$($this.IconText)" -match '^[A-Za-z0-9]{1,3}$')
    }

    [void] SetImage([string]$path) {
        $this.ImagePath = "$path"
        $this.OnPropertyChanged("ImagePath")
    }

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
