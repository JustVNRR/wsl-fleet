# ==============================================================================
# LE THÈME DE LA FENÊTRE
# ==============================================================================
# Le look de la fenêtre : sa police, sa taille, son thème de couleurs
# (phosphor, amber...) et sa variante (Dark, Light). Les défauts sont ceux du
# fichier d'aujourd'hui. Les champs sont hidden — la discipline plutôt que le
# verrou — et la porte est la méthode : un couple Get/Set. La forme seule : le
# fichier gui-settings.json se lit et s'écrit au dépôt ; le chargement des
# couleurs reste à la fenêtre.
class WpfTheme {
    hidden [string]$FontFamily = "VT323"
    hidden [int]$FontSize = 15
    hidden [string]$ColorTheme = "phosphor"
    hidden [string]$Variant = "Dark"

    WpfTheme() {}

    [string] GetFontFamily() { return $this.FontFamily }
    [void] SetFontFamily([string]$family) { $this.FontFamily = $family }

    [int] GetFontSize() { return $this.FontSize }
    [void] SetFontSize([int]$size) { $this.FontSize = $size }

    [string] GetColorTheme() { return $this.ColorTheme }
    [void] SetColorTheme([string]$colourTheme) { $this.ColorTheme = $colourTheme }

    [string] GetVariant() { return $this.Variant }
    [void] SetVariant([string]$variant) { $this.Variant = $variant }

    # La fenêtre en une ligne — qui la montre décide où et quand.
    [string] ToString() {
        return "font '$($this.FontFamily)' at $($this.FontSize), $($this.ColorTheme) ($($this.Variant))"
    }
}
