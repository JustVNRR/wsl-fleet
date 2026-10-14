# ==============================================================================
# LES RÉGLAGES — LE VIEWMODEL
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout lui-même ce qu'il
# tire.
using module .\BaseViewModel.psm1
using module ..\Dto\WpfDto.psm1
using module ..\Dto\PackCatalogDto.psm1
using module ..\Tools\Helpers.psm1

# Les lignes des listes : le libellé que la liste montre. De VRAIES classes —
# WPF ne lit que les vraies propriétés .NET : un PSCustomObject s'afficherait
# brut (« @{Name=…; Label=…} », mesuré sur sa machine).
class SettingsLabelRow {
    [string]$Name = ""
    [string]$Label = ""
}

class SettingsPackRow {
    [string]$Name = ""
    [string]$Family = ""
    [string]$Description = ""
    [string]$Label = ""
}

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

    # L'état bindable : de VRAIES propriétés de classe — WPF ne lit que
    # celles-là. Les listes montrent leurs LIBELLÉS, en chaînes (WPF les
    # affiche sûrement — mesuré : la taille s'affiche, un DisplayMemberPath
    # sur nos objets reste muet), les lignes gardent le reste.
    [object[]]$Fonts = @()
    [string[]]$FontLabels = @()
    [int]$FontIndex = 0
    [string[]]$Sizes = @()
    [int]$SizeIndex = 0
    [object[]]$Colours = @()
    [string[]]$ColourLabels = @()
    [int]$ColourIndex = 0
    [object[]]$Packs = @()
    [string[]]$PackLabels = @()
    [int]$PackIndex = -1
    [string]$Root = ""
    [string]$Variant = "Dark"
    [string]$ThemeError = ""
    [string]$CatalogueError = ""
    [bool]$CanTheme = $false
    [bool]$CanPack = $false

    hidden [string]$_newRoot = ""

    SettingsViewModel([object]$wpfService, [object]$catalogueService, [object]$fleetService, [string]$assetsDir) {
        $this._wpf = $wpfService
        $this._catalogue = $catalogueService
        $this._fleet = $fleetService
        $this._assets = $assetsDir

        try { $theme = $this._wpf.GetTheme() } catch { $theme = $null }
        $this.Variant = if ($theme -and "$($theme.Variant)") { "$($theme.Variant)" } else { "Dark" }
        try { $this.Root = "$($this._fleet.GetRoot())" } catch { }
        try { $themes = @($this._wpf.GetColorThemes()) } catch { $themes = @() }
        try { $choices = @($this._wpf.GetFontChoices()) } catch { $choices = @() }
        try { $stock = @($this._catalogue.GetAllPacks()) } catch { $stock = @() }

        # La police : les familles reçues, celle qu'on porte marquée et
        # sélectionnée — prépendue quand elle n'y est pas.
        $fontNames = @()
        foreach ($font in @($choices)) { $fontNames += "$font" }
        if ($theme -and $fontNames -notcontains "$($theme.FontFamily)") { $fontNames = @("$($theme.FontFamily)") + $fontNames }
        $fontRows = @()
        for ($i = 0; $i -lt $fontNames.Count; $i++) {
            $fontRows += [SettingsLabelRow]@{ Name = "$($fontNames[$i])"; Label = "$($fontNames[$i])" }
        }
        $this.Fonts = @($fontRows)
        $this.FontLabels = @($fontRows | ForEach-Object { "$($_.Label)" })
        if ($theme) {
            for ($i = 0; $i -lt $fontRows.Count; $i++) { if ("$($fontRows[$i].Name)" -eq "$($theme.FontFamily)") { $this.FontIndex = $i } }
        }

        # $sizeList : une locale ne peut pas porter le nom d'une propriété
        # réelle (mesuré au parse).
        $sizeList = @("11", "13", "15", "17", "19")
        if ($theme -and $sizeList -notcontains "$([int]$theme.FontSize)") { $sizeList = @("$([int]$theme.FontSize)") + $sizeList }
        $this.Sizes = @($sizeList)
        if ($theme) {
            for ($i = 0; $i -lt $sizeList.Count; $i++) { if ("$($sizeList[$i])" -eq "$([int]$theme.FontSize)") { $this.SizeIndex = $i } }
        }

        # Les thèmes : celui qu'on porte marqué — prépendu (sous « Default »)
        # quand il n'y est pas.
        $sets = @()
        if ($theme -and (-not "$($theme.ColorTheme)" -or @($themes) -notcontains "$($theme.ColorTheme)")) { $sets += "$($theme.ColorTheme)" }
        foreach ($name in @($themes)) { $sets += "$name" }
        $colourRows = @()
        foreach ($set in $sets) {
            $colourRows += [SettingsLabelRow]@{ Name = "$set"; Label = if ($set) { "$set" } else { "Default" } }
        }
        $this.Colours = @($colourRows)
        $this.ColourLabels = @($colourRows | ForEach-Object { "$($_.Label)" })
        if ($theme) {
            for ($i = 0; $i -lt $colourRows.Count; $i++) { if ("$($colourRows[$i].Name)" -eq "$($theme.ColorTheme)") { $this.ColourIndex = $i } }
        }

        $this.Packs = @($this.PackRowsOf($stock))
        $this.PackLabels = @($this.Packs | ForEach-Object { "$($_.Label)" })
        if ($this.Packs.Count -gt 0) { $this.PackIndex = 0 }
        $this.CanTheme = $this.HasRealTheme()
        $this.CanPack = ($this.PackIndex -ge 0)
    }

    # Les liens XAML sont à sens unique : la vue relaie chaque choix ici — le
    # choix, la garde et le cri des mains vivent d'un seul côté.
    [void] SetFontIndex([int]$value) {
        if ($this.FontIndex -ne $value) {
            $this.FontIndex = $value
            $this.OnPropertyChanged("FontIndex")
        }
    }

    [void] SetSizeIndex([int]$value) {
        if ($this.SizeIndex -ne $value) {
            $this.SizeIndex = $value
            $this.OnPropertyChanged("SizeIndex")
        }
    }

    [void] SetColourIndex([int]$value) {
        if ($this.ColourIndex -ne $value) {
            $this.ColourIndex = $value
            $this.OnPropertyChanged("ColourIndex")
            $this.CanTheme = $this.HasRealTheme()
            $this.OnPropertyChanged("CanTheme")
        }
    }

    [void] SetPackIndex([int]$value) {
        if ($this.PackIndex -ne $value) {
            $this.PackIndex = $value
            $this.OnPropertyChanged("PackIndex")
            $this.CanPack = ($this.PackIndex -ge 0)
            $this.OnPropertyChanged("CanPack")
        }
    }

    hidden [object[]] PackRowsOf([object[]]$packs) {
        $rows = @()
        foreach ($pack in @($packs | Sort-Object Name)) {
            $rows += [SettingsPackRow]@{ Name = "$($pack.Name)"; Family = "$($pack.Family)"; Description = "$($pack.Description)"; Label = "$($pack.Name) ($($pack.Family))" }
        }
        return @($rows)
    }

    # --- ce que la vue lit, par méthode ---------------------------------------

    [string] SelectedFont() {
        if ($this.Fonts.Count -eq 0) { return "" }
        $at = [Math]::Max(0, [Math]::Min($this.FontIndex, $this.Fonts.Count - 1))
        return "$($this.Fonts[$at].Name)"
    }

    [int] SelectedSize() {
        if ($this.Sizes.Count -eq 0) { return 15 }
        $at = [Math]::Max(0, [Math]::Min($this.SizeIndex, $this.Sizes.Count - 1))
        return [int]$this.Sizes[$at]
    }

    [string] SelectedColour() {
        if ($this.Colours.Count -eq 0) { return "" }
        $at = [Math]::Max(0, [Math]::Min($this.ColourIndex, $this.Colours.Count - 1))
        return "$($this.Colours[$at].Name)"
    }

    [object] SelectedPack() {
        if ($this.PackIndex -lt 0 -or $this.PackIndex -ge $this.Packs.Count) { return $null }
        return $this.Packs[$this.PackIndex]
    }

    [bool] HasRealTheme() {
        return [bool]($this.SelectedColour())
    }

    [bool] HasTheme([string]$name) {
        foreach ($row in $this.Colours) { if ("$($row.Name)" -eq "$name") { return $true } }
        return $false
    }

    # Le look choisi — le VM le rend entier en se fermant, et la vue rafraîchit
    # le contexte des fenêtres dessus.
    [object] Picked() {
        return [PSCustomObject]@{
            FontFamily = $this.SelectedFont()
            FontSize   = $this.SelectedSize()
            ColorTheme = $this.SelectedColour()
            Variant    = $this.Variant
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
        $this.Fonts = @($this.Fonts) + @([SettingsLabelRow]@{ Name = "$familyName"; Label = "$familyName  (just uploaded)" })
        $this.FontLabels = @($this.Fonts | ForEach-Object { "$($_.Label)" })
        $this.FontIndex = $this.Fonts.Count - 1
        $this.OnPropertyChanged("Fonts")
        $this.OnPropertyChanged("FontLabels")
        $this.OnPropertyChanged("FontIndex")
    }

    [void] FailTheme([string]$message) {
        $this.ThemeError = $message
        $this.OnPropertyChanged("ThemeError")
    }

    [void] ClearThemeError() {
        $this.ThemeError = ""
        $this.OnPropertyChanged("ThemeError")
    }

    # Un thème téléversé — déjà jugé par la vue (WPF seul sait lire un
    # dictionnaire) : posé par le service, la ligne ajoutée ou remplacée.
    [void] UploadTheme([string]$source, [string]$name) {
        try { $null = $this._wpf.UploadTheme($source) } catch { return }
        $existing = -1
        for ($i = 0; $i -lt $this.Colours.Count; $i++) { if ("$($this.Colours[$i].Name)" -eq "$name") { $existing = $i; break } }
        if ($existing -lt 0) {
            $this.Colours = @($this.Colours) + @([SettingsLabelRow]@{ Name = "$name"; Label = "$name  (just uploaded)" })
            $this.ColourLabels = @($this.Colours | ForEach-Object { "$($_.Label)" })
            $existing = $this.Colours.Count - 1
            $this.OnPropertyChanged("Colours")
            $this.OnPropertyChanged("ColourLabels")
        }
        $this.ColourIndex = $existing
        $this.OnPropertyChanged("ColourIndex")
        $this.CanTheme = $this.HasRealTheme()
        $this.OnPropertyChanged("CanTheme")
    }

    [string] ThemePathFor([string]$name) {
        if ($name) { return (Join-Path (Join-Path $this._assets "themes") "$name.xaml") }
        return (Join-Path (Join-Path (Split-Path $this._assets -Parent) "src\windows\Views\WPF") "theme.xaml")
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
        $kept = @($this.Colours | Where-Object { "$($_.Name)" -ne "$name" })
        $this.Colours = @($kept)
        $this.ColourLabels = @($this.Colours | ForEach-Object { "$($_.Label)" })
        $this.ColourIndex = if ($kept.Count -gt 0) { [Math]::Min($this.ColourIndex, $kept.Count - 1) } else { 0 }
        $this.OnPropertyChanged("Colours")
        $this.OnPropertyChanged("ColourLabels")
        $this.OnPropertyChanged("ColourIndex")
        $this.CanTheme = $this.HasRealTheme()
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
        $this.Packs = @($this.PackRowsOf($refreshed))
        $this.PackLabels = @($this.Packs | ForEach-Object { "$($_.Label)" })
        $this.PackIndex = 0
        if ($select) {
            for ($i = 0; $i -lt $this.Packs.Count; $i++) { if ("$($this.Packs[$i].Name)" -eq "$select") { $this.PackIndex = $i; break } }
        }
        $this.OnPropertyChanged("Packs")
        $this.OnPropertyChanged("PackLabels")
        $this.OnPropertyChanged("PackIndex")
        $this.CanPack = ($this.PackIndex -ge 0)
        $this.OnPropertyChanged("CanPack")
    }

    [void] OpenPack() {
        $row = $this.SelectedPack()
        if (-not $row) { return }
        try { $this._catalogue.OpenPackFolder("$($row.Name)") } catch {
            $this.CatalogueError = "The folder did not open: $($_.Exception.Message)"
            $this.OnPropertyChanged("CatalogueError")
        }
    }

    # Dupliquer : la petite fenêtre répond le nom et la description, le
    # service copie le dossier sous le nom neuf, la liste se relit.
    [void] DuplicatePack() {
        $row = $this.SelectedPack()
        if (-not $row) { return }
        $taken = @($this.Packs | ForEach-Object { "$($_.Name)" })
        $answer = $this.OpenBox("PackDuplicate", @("$($row.Name)", "$($row.Description)", $taken))
        if ($null -eq $answer) { return }
        try {
            $dto = [CreatePackDto]::new()
            $dto.SourceName = "$($row.Name)"
            $dto.NewName = "$($answer.Name)"
            $dto.Description = "$($answer.Description)"
            $this._catalogue.CreatePack($dto)
        } catch {
            $this.CatalogueError = "The pack was not duplicated: $($_.Exception.Message)"
            $this.OnPropertyChanged("CatalogueError")
            return
        }
        $this.RefreshPacks("$($answer.Name)")
    }

    [void] DeletePack() {
        $row = $this.SelectedPack()
        if (-not $row) { return }
        try { $this._catalogue.DeletePack("$($row.Name)") } catch {
            $this.CatalogueError = "The pack was not removed: $($_.Exception.Message)"
            $this.OnPropertyChanged("CatalogueError")
            return
        }
        $this.RefreshPacks("")
    }

    # --- la racine ------------------------------------------------------------

    # Le crayon : la question du déplacement (sa fenêtre), et un dossier
    # confirmé ferme les Réglages — l'entrée le portera au migrate.
    [void] EditRoot() {
        $chosen = $this.OpenBox("RootMove", @($this.Root))
        if (-not $chosen) { return }
        $this._newRoot = "$chosen"
        $this.Root = "$chosen"
        $this.OnPropertyChanged("Root")
        $this.RequestClose()
    }
}
