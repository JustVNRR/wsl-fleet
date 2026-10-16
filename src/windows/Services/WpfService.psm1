using module ..\Dtos\WpfDto.psm1
using module ..\Repositories\ConfigRepository.psm1
using module ..\Repositories\TerminalRepository.psm1
using module ..\Mappers\WpfMapper.psm1

class WpfService {
    hidden [ConfigRepository]$Config
    hidden [TerminalRepository]$Terminal
    hidden [WpfMapper]$Map

    WpfService([ConfigRepository]$config, [TerminalRepository]$terminal) {
        $this.Config = $config
        $this.Terminal = $terminal
        $this.Map = [WpfMapper]::new()
    }

    [WpfThemeDto] GetTheme() {
        return $this.Map.ToThemeDto($this.Config.GetWpfTheme())
    }

    [void] SetFontFamily([string]$family) {
        $theme = $this.Config.GetWpfTheme()
        $theme.SetFontFamily($family)
        $this.Config.SaveWpfTheme($theme)
    }

    [void] SetFontSize([int]$size) {
        $theme = $this.Config.GetWpfTheme()
        $theme.SetFontSize($size)
        $this.Config.SaveWpfTheme($theme)
    }

    [void] SetColorTheme([string]$colourTheme) {
        $theme = $this.Config.GetWpfTheme()
        $theme.SetColorTheme($colourTheme)
        $this.Config.SaveWpfTheme($theme)
    }

    [void] SetVariant([string]$variant) {
        $theme = $this.Config.GetWpfTheme()
        $theme.SetVariant($variant)
        $this.Config.SaveWpfTheme($theme)
    }

    [string[]] GetColorThemes() {
        return @($this.Config.GetThemeNames())
    }

    [string] UploadFont([string]$source) {
        return $this.Config.CopyFont($source)
    }

    [string] UploadTheme([string]$source) {
        return $this.Config.CopyTheme($source)
    }

    [void] DeleteTheme([string]$name) {
        $this.Config.DeleteTheme($name)
    }

    [void] OpenTheme([string]$name) {
        $this.Config.OpenTheme($name)
    }

    [void] ExportTheme([ExportThemeDto]$dto) {
        Copy-Item -LiteralPath $dto.Source -Destination $dto.Target -Force -ErrorAction Stop
    }

    [string[]] GetFontChoices() {
        $names = @()
        foreach ($name in @($this.Config.GetFontNames())) {
            if ($names -notcontains $name) { $names += $name }
        }
        foreach ($font in @($this.Terminal.GetTerminalFonts())) {
            if ($names -notcontains $font.Name) { $names += $font.Name }
        }
        return @($names)
    }
}
