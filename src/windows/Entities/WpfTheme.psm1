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

    [string] ToString() {
        return "font '$($this.FontFamily)' at $($this.FontSize), $($this.ColorTheme) ($($this.Variant))"
    }
}
