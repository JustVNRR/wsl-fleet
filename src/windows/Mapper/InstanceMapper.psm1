# ==============================================================================
# LE MAPPEUR DE L'INSTANCE
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout un type qu'il a tiré
# lui-même.
using module ..\Model\WslInstance.psm1
using module ..\Model\WslTheme.psm1
using module ..\Model\WslPack.psm1
using module ..\Dto\InstanceDto.psm1
# WslPackDto vit chez le PackCatalog — un type se résout là où il se lit.
using module ..\Dto\PackCatalogDto.psm1

# Les conversions entre le Modèle et les Dto — le service les appelle au lieu
# de recopier les champs, et chaque conversion ne vit qu'ici. Les méthodes se
# créent au fur et à mesure de l'implémentation des services : celles-ci sont
# celles que les méthodes déjà dessinées demandent.
class InstanceMapper {
    InstanceMapper() {}

    # L'instance en ligne d'index — ce que la liste affiche, et rien de plus.
    [WslIndexDto] ToIndexDto([WslInstance]$instance) {
        $dto = [WslIndexDto]::new()
        $dto.Name = $instance.GetName()
        $dto.Size = $instance.GetSize()
        $dto.IsArchive = $instance.GetIsArchive()
        return $dto
    }

    # Le dessin de l'icône d'un thème, en Dto.
    [WslIconDto] ToIconDto([WslTheme]$theme) {
        $icon = $theme.GetIcon()
        $dto = [WslIconDto]::new()
        $dto.Text = $icon.Text
        $dto.Top = $icon.Top
        $dto.Bottom = $icon.Bottom
        $dto.TextColor = $icon.TextColor
        return $dto
    }

    # Le pack déclaré en ligne — ce que les fenêtres montrent.
    [WslPackDto] ToPackDto([WslPack]$pack) {
        $dto = [WslPackDto]::new()
        $dto.Name = $pack.GetName()
        $dto.Description = $pack.GetDescription()
        $dto.Family = $pack.GetFamily()
        return $dto
    }

    # Ce que l'instance porte, en réponse lisible.
    [GetAppearanceResponseDto] ToAppearanceResponse([WslTheme]$theme, [bool]$hasFragment) {
        $dto = [GetAppearanceResponseDto]::new()
        $dto.Font = $theme.GetFontName()
        $dto.ColourScheme = $theme.GetColorScheme()
        $dto.Icon = $this.ToIconDto($theme)
        $dto.HasFragment = $hasFragment
        $dto.IconPath = $theme.GetIconPath()
        return $dto
    }

    # Les changements demandés, en thème à appliquer : un thème nu qui ne
    # porte que ce que le Dto donne — le service le fond dans celui de
    # l'instance, sans toucher au reste.
    [WslTheme] FromSetAppearanceDto([SetAppearanceDto]$dto) {
        $theme = [WslTheme]::new()
        if ($dto.Font) { $theme.SetFont($dto.Font) }
        if ($dto.ColourScheme) { $theme.SetColourScheme($dto.ColourScheme) }
        if ($dto.Icon) { $theme.SetIcon($dto.Icon) }
        if ($dto.IconImage) { $theme.SetIconPath($dto.IconImage) }
        return $theme
    }
}
