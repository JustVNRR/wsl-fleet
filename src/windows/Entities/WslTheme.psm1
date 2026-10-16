class WslTheme {
    hidden [string]$IconPath
    hidden [string]$ColorScheme
    hidden [string]$FontName
    hidden [string]$TabTitle

    hidden [string]$IconText
    hidden [string]$IconTop
    hidden [string]$IconBottom
    hidden [string]$IconTextColor

    WslTheme() {}

    WslTheme([string]$icon, [string]$scheme, [string]$font, [string]$title) {
        $this.IconPath    = $icon
        $this.ColorScheme = $scheme
        $this.FontName    = $font
        $this.TabTitle    = $title
    }

    [string] GetIconPath() { return $this.IconPath }
    [void] SetIconPath([string]$path) { $this.IconPath = $path }

    [string] GetColorScheme() { return $this.ColorScheme }
    [void] SetColourScheme([string]$scheme) { $this.ColorScheme = $scheme }

    [string] GetFontName() { return $this.FontName }
    [void] SetFont([string]$font) { $this.FontName = $font }

    [string] GetTabTitle() { return $this.TabTitle }
    [void] SetTabTitle([string]$title) { $this.TabTitle = $title }

    [object] GetIcon() {
        return [PSCustomObject]@{
            Text      = $this.IconText
            Top       = $this.IconTop
            Bottom    = $this.IconBottom
            TextColor = $this.IconTextColor
        }
    }

    [void] SetIcon([object]$drawing) {
        foreach ($colour in @($drawing.Top, $drawing.Bottom, $drawing.TextColor)) {
            if ($colour -and $colour -notmatch '^#[0-9A-Fa-f]{6}$') {
                throw "'$colour' is not a colour (#RRGGBB)."
            }
        }
        $this.IconText      = $drawing.Text
        $this.IconTop       = $drawing.Top
        $this.IconBottom    = $drawing.Bottom
        $this.IconTextColor = $drawing.TextColor
    }

    static [WslTheme] Default([string]$tabTitle) {
        return [WslTheme]::new($null, "One Half Dark", "MesloLGS NF", $tabTitle)
    }

    [string] ToString() {
        return "font '$($this.FontName)', colours '$($this.ColorScheme)'"
    }
}
