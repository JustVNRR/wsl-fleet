using module ..\Entities\WslInstance.psm1
using module ..\Entities\WslTheme.psm1
using module ..\Entities\WslPack.psm1
using module ..\Dtos\InstanceDto.psm1
using module ..\Dtos\PackCatalogDto.psm1

class InstanceMapper {
    InstanceMapper() {}

    [WslIndexDto] ToIndexDto([WslInstance]$instance) {
        $dto = [WslIndexDto]::new()
        $dto.Name = $instance.GetName()
        $dto.Size = $instance.GetSize()
        $dto.IsArchive = $instance.GetIsArchive()
        return $dto
    }

    [WslIconDto] ToIconDto([WslTheme]$theme) {
        $icon = $theme.GetIcon()
        $dto = [WslIconDto]::new()
        $dto.Text = $icon.Text
        $dto.Top = $icon.Top
        $dto.Bottom = $icon.Bottom
        $dto.TextColor = $icon.TextColor
        return $dto
    }

    [WslPackDto] ToPackDto([WslPack]$pack) {
        $dto = [WslPackDto]::new()
        $dto.Name = $pack.GetName()
        $dto.Description = $pack.GetDescription()
        $dto.Family = $pack.GetFamily()
        return $dto
    }

    [GetAppearanceResponseDto] ToAppearanceResponse([WslTheme]$theme, [bool]$hasFragment) {
        $dto = [GetAppearanceResponseDto]::new()
        $dto.Font = $theme.GetFontName()
        $dto.ColourScheme = $theme.GetColorScheme()
        $dto.Icon = $this.ToIconDto($theme)
        $dto.HasFragment = $hasFragment
        $dto.IconPath = $theme.GetIconPath()
        return $dto
    }

    [WslTheme] FromSetAppearanceDto([SetAppearanceDto]$dto) {
        $theme = [WslTheme]::new()
        if ($dto.Font) { $theme.SetFont($dto.Font) }
        if ($dto.ColourScheme) { $theme.SetColourScheme($dto.ColourScheme) }
        if ($dto.Icon) { $theme.SetIcon($dto.Icon) }
        if ($dto.IconImage) { $theme.SetIconPath($dto.IconImage) }
        return $theme
    }
}
