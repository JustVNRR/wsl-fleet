# ==============================================================================
# LES RÉGLAGES — LE VIEWMODEL
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout lui-même ce qu'il
# tire.
using module .\BaseViewModel.psm1
using module ..\Dto\WpfDto.psm1
using module ..\Dto\PackCatalogDto.psm1
using module ..\Tools\Helpers.psm1

# La fenêtre Réglages : la racine (montrée ; le crayon ouvre la question du
# déplacement), la face (police, taille, thème — EN DIRECT, la vue repeint),
# et le catalogue (les packs du dépôt : ouvrir le dossier, dupliquer,
# supprimer). Le look choisi se rend entier en se fermant, et le dossier
# d'arrivée s'il y en a un.
#
# Il a les services en main : la face s'écrit au WpfService, le catalogue se
# lit et se range au PackCatalogService — les portes liées de l'ancien monde
# n'ont plus lieu d'être. Ce qui est du WPF pur (lire la famille d'un fichier
# de police, charger un thème pour le juger) reste chez la vue, qui rappelle
# ici avec sa réponse.
class SettingsViewModel : BaseViewModel {
    hidden [object]$_wpf = $null
    hidden [object]$_catalogue = $null
    hidden [object]$_fleet = $null
    hidden [string]$_assets = ""
    hidden [string]$_views = ""

    hidden [object[]]$_fontRows = @()
    hidden [int]$_fontIndex = 0
    hidden [string[]]$_sizes = @()
    hidden [int]$_sizeIndex = 0
    hidden [object[]]$_colourRows = @()
    hidden [int]$_colourIndex = 0
    hidden [object[]]$_packRows = @()
    hidden [int]$_packIndex = -1

    hidden [string]$_root = ""
    hidden [string]$_variant = "Dark"
    hidden [string]$_themeError = ""
    hidden [string]$_catalogueError = ""
    hidden [string]$_newRoot = ""

    SettingsViewModel([object]$wpfService, [object]$catalogueService, [object]$fleetService, [string]$assetsDir, [string]$viewsRoot) {
        $this._wpf = $wpfService
        $this._catalogue = $catalogueService
        $this._fleet = $fleetService
        $this._assets = $assetsDir
        $this._views = $viewsRoot

        try { $theme = $this._wpf.GetTheme() } catch { $theme = $null }
        $this._variant = if ($theme -and "$($theme.Variant)") { "$($theme.Variant)" } else { "Dark" }
        try { $this._root = "$($this._fleet.GetRoot())" } catch { }
        try { $themes = @($this._wpf.GetColorThemes()) } catch { $themes = @() }
        try { $fonts = @($this._wpf.GetFontChoices()) } catch { $fonts = @() }
        try { $packs = @($this._catalogue.GetAllPacks()) } catch { $packs = @() }

        # La police : les familles reçues, celle qu'on porte marquée et
        # sélectionnée — prépendue quand elle n'y est pas.
        $fontNames = @()
        foreach ($font in @($fonts)) { $fontNames += "$font" }
        if ($theme -and $fontNames -notcontains "$($theme.FontFamily)") { $fontNames = @("$($theme.FontFamily)") + $fontNames }
        $fontRows = @()
        for ($i = 0; $i -lt $fontNames.Count; $i++) {
            $fontRows += [PSCustomObject]@{ Name = "$($fontNames[$i])"; Label = "$($fontNames[$i])" }
        }
        $this._fontRows = @($fontRows)
        if ($theme) {
            for ($i = 0; $i -lt $fontRows.Count; $i++) { if ("$($fontRows[$i].Name)" -eq "$($theme.FontFamily)") { $this._fontIndex = $i } }
        }

        $sizes = @("11", "13", "15", "17", "19")
        if ($theme -and $sizes -notcontains "$([int]$theme.FontSize)") { $sizes = @("$([int]$theme.FontSize)") + $sizes }
        $this._sizes = @($sizes)
        if ($theme) {
            for ($i = 0; $i -lt $sizes.Count; $i++) { if ("$($sizes[$i])" -eq "$([int]$theme.FontSize)") { $this._sizeIndex = $i } }
        }

        # Les thèmes : celui qu'on porte marqué — prépendu (sous « Default »)
        # quand il n'y est pas.
        $sets = @()
        if ($theme -and (-not "$($theme.ColorTheme)" -or @($themes) -notcontains "$($theme.ColorTheme)")) { $sets += "$($theme.ColorTheme)" }
        foreach ($name in @($themes)) { $sets += "$name" }
        $colourRows = @()
        foreach ($set in $sets) {
            $colourRows += [PSCustomObject]@{ Name = "$set"; Label = if ($set) { "$set" } else { "Default" } }
        }
        $this._colourRows = @($colourRows)
        if ($theme) {
            for ($i = 0; $i -lt $colourRows.Count; $i++) { if ("$($colourRows[$i].Name)" -eq "$($theme.ColorTheme)") { $this._colourIndex = $i } }
        }

        $this._packRows = @($this.PackRowsOf($packs))
        if ($this._packRows.Count -gt 0) { $this._packIndex = 0 }

        $this.AddProperty("Root", { return $this._root }, {
            param($value)
            if ($this._root -ne "$value") { $this._root = "$value"; $this.OnPropertyChanged("Root") }
        })
        $this.AddProperty("Fonts", { return $this._fontRows }, { param($value) })
        $this.AddProperty("FontIndex", { return $this._fontIndex }, {
            param($value)
            if ($this._fontIndex -ne [int]$value) { $this._fontIndex = [int]$value; $this.OnPropertyChanged("FontIndex") }
        })
        $this.AddProperty("Sizes", { return $this._sizes }, { param($value) })
        $this.AddProperty("SizeIndex", { return $this._sizeIndex }, {
            param($value)
            if ($this._sizeIndex -ne [int]$value) { $this._sizeIndex = [int]$value; $this.OnPropertyChanged("SizeIndex") }
        })
        $this.AddProperty("Colours", { return $this._colourRows }, { param($value) })
        $this.AddProperty("ColourIndex", { return $this._colourIndex }, {
            param($value)
            if ($this._colourIndex -ne [int]$value) {
                $this._colourIndex = [int]$value
                $this.OnPropertyChanged("ColourIndex")
                $this.OnPropertyChanged("CanTheme")
            }
        })
        $this.AddProperty("Packs", { return $this._packRows }, { param($value) })
        $this.AddProperty("PackIndex", { return $this._packIndex }, {
            param($value)
            if ($this._packIndex -ne [int]$value) {
                $this._packIndex = [int]$value
                $this.OnPropertyChanged("PackIndex")
                $this.OnPropertyChanged("CanPack")
            }
        })
        # Les mains : un thème qui a un fichier (pas « Default »), un pack
        # choisi.
        $this.AddProperty("CanTheme", { return $this.HasRealTheme() }, { param($value) })
        $this.AddProperty("CanPack", { return ($this._packIndex -ge 0) }, { param($value) })
        $this.AddProperty("Variant", { return $this._variant }, {
            param($value)
            if ($this._variant -ne "$value") { $this._variant = "$value"; $this.OnPropertyChanged("Variant") }
        })
        $this.AddProperty("ThemeError", { return $this._themeError }, {
            param($value)
            if ($this._themeError -ne "$value") { $this._themeError = "$value"; $this.OnPropertyChanged("ThemeError") }
        })
        $this.AddProperty("CatalogueError", { return $this._catalogueError }, {
            param($value)
            if ($this._catalogueError -ne "$value") { $this._catalogueError = "$value"; $this.OnPropertyChanged("CatalogueError") }
        })
    }

    hidden [object[]] PackRowsOf([object[]]$packs) {
        $rows = @()
        foreach ($pack in @($packs | Sort-Object Name)) {
            $rows += [PSCustomObject]@{ Name = "$($pack.Name)"; Family = "$($pack.Family)"; Description = "$($pack.Description)"; Label = "$($pack.Name) ($($pack.Family))" }
        }
        return @($rows)
    }

    # --- ce que la vue lit, par méthode ---------------------------------------

    [string] SelectedFont() {
        if ($this._fontRows.Count -eq 0) { return "" }
        $at = [Math]::Max(0, [Math]::Min($this._fontIndex, $this._fontRows.Count - 1))
        return "$($this._fontRows[$at].Name)"
    }

    [int] SelectedSize() {
        if ($this._sizes.Count -eq 0) { return 15 }
        $at = [Math]::Max(0, [Math]::Min($this._sizeIndex, $this._sizes.Count - 1))
        return [int]$this._sizes[$at]
    }

    [string] SelectedColour() {
        if ($this._colourRows.Count -eq 0) { return "" }
        $at = [Math]::Max(0, [Math]::Min($this._colourIndex, $this._colourRows.Count - 1))
        return "$($this._colourRows[$at].Name)"
    }

    [object] SelectedPack() {
        if ($this._packIndex -lt 0 -or $this._packIndex -ge $this._packRows.Count) { return $null }
        return $this._packRows[$this._packIndex]
    }

    [bool] HasRealTheme() {
        return [bool]($this.SelectedColour())
    }

    [bool] HasTheme([string]$name) {
        foreach ($row in $this._colourRows) { if ("$($row.Name)" -eq "$name") { return $true } }
        return $false
    }

    # Le look choisi — le VM le rend entier en se fermant, et la vue rafraîchit
    # le contexte des fenêtres dessus.
    [object] Picked() {
        return [PSCustomObject]@{
            FontFamily = $this.SelectedFont()
            FontSize   = $this.SelectedSize()
            ColorTheme = $this.SelectedColour()
            Variant    = $this._variant
            NewRoot    = $this._newRoot
        }
    }

    # --- la face : les fichiers -----------------------------------------------

    # Une police téléversée : le fichier posé par le service, la famille lue
    # par la VUE (WPF seul sait la dire) qui rappelle ici avec son nom.
    [string] UploadFont([string]$source) {
        try { return "$($this._wpf.UploadFont($source))" } catch { return "" }
    }

    [void] AddFont([string]$familyName) {
        if (-not $familyName) { return }
        $this._fontRows = @($this._fontRows) + @([PSCustomObject]@{ Name = "$familyName"; Label = "$familyName  (just uploaded)" })
        $this._fontIndex = $this._fontRows.Count - 1
        $this.OnPropertyChanged("Fonts")
        $this.OnPropertyChanged("FontIndex")
    }

    [void] FailTheme([string]$message) {
        $this._themeError = $message
        $this.OnPropertyChanged("ThemeError")
    }

    [void] ClearThemeError() {
        $this._themeError = ""
        $this.OnPropertyChanged("ThemeError")
    }

    # Un thème téléversé — déjà jugé par la vue (WPF seul sait lire un
    # dictionnaire) : posé par le service, la ligne ajoutée ou remplacée.
    [void] UploadTheme([string]$source, [string]$name) {
        try { $null = $this._wpf.UploadTheme($source) } catch { return }
        $existing = -1
        for ($i = 0; $i -lt $this._colourRows.Count; $i++) { if ("$($this._colourRows[$i].Name)" -eq "$name") { $existing = $i; break } }
        if ($existing -lt 0) {
            $this._colourRows = @($this._colourRows) + @([PSCustomObject]@{ Name = "$name"; Label = "$name  (just uploaded)" })
            $existing = $this._colourRows.Count - 1
            $this.OnPropertyChanged("Colours")
        }
        $this._colourIndex = $existing
        $this.OnPropertyChanged("ColourIndex")
        $this.OnPropertyChanged("CanTheme")
    }

    [string] ThemePathFor([string]$name) {
        if ($name) { return (Join-Path (Join-Path $this._assets "themes") "$name.xaml") }
        return (Join-Path $this._views "theme.xaml")
    }

    [string] ThemeFileFor([string]$name) {
        if ($name) { return "$name.xaml" }
        return "theme.xaml"
    }

    [void] ExportTheme([string]$name, [string]$target) {
        if (-not $target) { return }
        try {
            $exp = [ExportThemeDto]::new()
            $exp.Source = $this.ThemePathFor($name)
            $exp.Target = $target
            $this._wpf.ExportTheme($exp)
        } catch { }
    }

    [void] DeleteTheme([string]$name) {
        if (-not $name) { return }
        try { $this._wpf.DeleteTheme($name) } catch { return }
        $kept = @($this._colourRows | Where-Object { "$($_.Name)" -ne "$name" })
        $this._colourRows = @($kept)
        $this._colourIndex = if ($kept.Count -gt 0) { [Math]::Min($this._colourIndex, $kept.Count - 1) } else { 0 }
        $this.OnPropertyChanged("Colours")
        $this.OnPropertyChanged("ColourIndex")
        $this.OnPropertyChanged("CanTheme")
    }

    [void] OpenTheme([string]$name) {
        if (-not $name) { return }
        try { $this._wpf.OpenTheme($name) } catch {
            $this.FailTheme("The file did not open: $($_.Exception.Message)")
        }
    }

    # --- le catalogue ---------------------------------------------------------

    hidden [void] RefreshPacks([string]$select) {
        try { $refreshed = @($this._catalogue.GetAllPacks()) } catch { return }
        $this._packRows = @($this.PackRowsOf($refreshed))
        $this._packIndex = 0
        if ($select) {
            for ($i = 0; $i -lt $this._packRows.Count; $i++) { if ("$($this._packRows[$i].Name)" -eq "$select") { $this._packIndex = $i; break } }
        }
        $this.OnPropertyChanged("Packs")
        $this.OnPropertyChanged("PackIndex")
        $this.OnPropertyChanged("CanPack")
    }

    [void] OpenPack() {
        $row = $this.SelectedPack()
        if (-not $row) { return }
        try { $this._catalogue.OpenPackFolder("$($row.Name)") } catch {
            $this._catalogueError = "The folder did not open: $($_.Exception.Message)"
            $this.OnPropertyChanged("CatalogueError")
        }
    }

    # Dupliquer : la petite fenêtre répond le nom et la description, le
    # service copie le dossier sous le nom neuf, la liste se relit.
    [void] DuplicatePack() {
        $row = $this.SelectedPack()
        if (-not $row) { return }
        $taken = @($this._packRows | ForEach-Object { "$($_.Name)" })
        $answer = [BaseViewModel]::OpenFace($this._views, "PackDuplicate", @("$($row.Name)", "$($row.Description)", $taken))
        if ($null -eq $answer) { return }
        try {
            $dto = [CreatePackDto]::new()
            $dto.SourceName = "$($row.Name)"
            $dto.NewName = "$($answer.Name)"
            $dto.Description = "$($answer.Description)"
            $this._catalogue.CreatePack($dto)
        } catch {
            $this._catalogueError = "The pack was not duplicated: $($_.Exception.Message)"
            $this.OnPropertyChanged("CatalogueError")
            return
        }
        $this.RefreshPacks("$($answer.Name)")
    }

    [void] DeletePack() {
        $row = $this.SelectedPack()
        if (-not $row) { return }
        try { $this._catalogue.DeletePack("$($row.Name)") } catch {
            $this._catalogueError = "The pack was not removed: $($_.Exception.Message)"
            $this.OnPropertyChanged("CatalogueError")
            return
        }
        $this.RefreshPacks("")
    }

    # --- la racine ------------------------------------------------------------

    # Le crayon : la question du déplacement (sa fenêtre), et un dossier
    # confirmé ferme les Réglages — l'entrée le portera au migrate.
    [void] EditRoot() {
        $chosen = [BaseViewModel]::OpenFace($this._views, "RootMove", @($this._root))
        if (-not $chosen) { return }
        $this._newRoot = "$chosen"
        $this._root = "$chosen"
        $this.OnPropertyChanged("Root")
        $this.OnPropertyChanged("Done")
    }
}
