using module ..\Entities\WpfTheme.psm1
using module ..\Dtos\WpfDto.psm1

class WpfMapper {
    WpfMapper() {}

    [WpfThemeDto] ToThemeDto([WpfTheme]$theme) {
        $dto = [WpfThemeDto]::new()
        $dto.FontFamily = $theme.GetFontFamily()
        $dto.FontSize = $theme.GetFontSize()
        $dto.ColorTheme = $theme.GetColorTheme()
        $dto.Variant = $theme.GetVariant()
        return $dto
    }
}
