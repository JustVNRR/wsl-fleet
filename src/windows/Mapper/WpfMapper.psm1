# ==============================================================================
# LE MAPPEUR DE LA FENÊTRE
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout un type qu'il a tiré
# lui-même.
using module ..\Model\WpfTheme.psm1
using module ..\Dto\WpfDto.psm1

# Les conversions entre le Modèle de la fenêtre et ses Dto — le service les
# appelle au lieu de recopier les champs, et chaque conversion ne vit qu'ici.
# Les méthodes se créent au fur et à mesure de l'implémentation des services.
class WpfMapper {
    WpfMapper() {}

    # Le look de la fenêtre, en clair — ce que le service rend.
    [WpfThemeDto] ToThemeDto([WpfTheme]$theme) {
        $dto = [WpfThemeDto]::new()
        $dto.FontFamily = $theme.GetFontFamily()
        $dto.FontSize = $theme.GetFontSize()
        $dto.ColorTheme = $theme.GetColorTheme()
        $dto.Variant = $theme.GetVariant()
        return $dto
    }
}
