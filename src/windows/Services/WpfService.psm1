# ==============================================================================
# LA FENÊTRE — LE SERVICE
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout un type qu'il a tiré
# lui-même.
using module ..\Dtos\WpfDto.psm1
using module ..\Repositories\ConfigRepository.psm1
using module ..\Repositories\TerminalRepository.psm1
using module ..\Mappers\WpfMapper.psm1

# Le look de la fenêtre : le lire, le poser pièce par pièce, et les listes
# qu'il offre — les jeux de couleurs du dossier des thèmes, les familles que
# la fenêtre peut porter (le dossier des polices d'abord, l'installé sur la
# machine en dernier). La règle des Dto comme partout — XxxDto en entrée quand
# il y a à demander, XxxResponseDto en retour quand il y a à rendre ; un seul
# champ se passe nu. Le fichier gui-settings.json se lit et s'écrit au dépôt à
# chaque part posée : lire, changer, écrire — la lecture d'abord, ou l'écri-
# ture effacerait ce que le fichier portait. Le chargement des couleurs reste
# à la fenêtre.
class WpfService {
    hidden [ConfigRepository]$Config
    hidden [TerminalRepository]$Terminal
    hidden [WpfMapper]$Map

    WpfService([ConfigRepository]$config, [TerminalRepository]$terminal) {
        $this.Config = $config
        $this.Terminal = $terminal
        $this.Map = [WpfMapper]::new()
    }

    # Le look en cours, en clair — le fichier gui-settings.json, ses défauts
    # quand il n'en dit rien.
    [WpfThemeDto] GetTheme() {
        return $this.Map.ToThemeDto($this.Config.GetWpfTheme())
    }

    # La famille posée, gardée au fichier.
    [void] SetFontFamily([string]$family) {
        $theme = $this.Config.GetWpfTheme()
        $theme.SetFontFamily($family)
        $this.Config.SaveWpfTheme($theme)
    }

    # La taille posée, gardée au fichier.
    [void] SetFontSize([int]$size) {
        $theme = $this.Config.GetWpfTheme()
        $theme.SetFontSize($size)
        $this.Config.SaveWpfTheme($theme)
    }

    # Le jeu de couleurs posé, gardé au fichier.
    [void] SetColorTheme([string]$colourTheme) {
        $theme = $this.Config.GetWpfTheme()
        $theme.SetColorTheme($colourTheme)
        $this.Config.SaveWpfTheme($theme)
    }

    # La variante (Dark/Light) posée, gardée au fichier.
    [void] SetVariant([string]$variant) {
        $theme = $this.Config.GetWpfTheme()
        $theme.SetVariant($variant)
        $this.Config.SaveWpfTheme($theme)
    }

    # Les jeux de couleurs que la fenêtre peut porter — les fichiers du dossier
    # des thèmes, par leur nom.
    [string[]] GetColorThemes() {
        return @($this.Config.GetThemeNames())
    }

    # Une police téléversée : le dépôt la pose dans un dossier à elle — le
    # cache de polices ne remarque jamais un fichier ajouté à un dossier
    # qu'il connaît (mesuré), un dossier neuf est servi frais. Rend le
    # dossier : la famille s'y lit en WPF, côté fenêtre.
    [string] UploadFont([string]$source) {
        return $this.Config.CopyFont($source)
    }

    # Un thème téléversé : son fichier posé dans le dossier des thèmes, sous
    # son nom — un nom déjà pris s'écrase (le prompt l'a confirmé). La
    # validité du fichier se lit en WPF, côté fenêtre.
    [string] UploadTheme([string]$source) {
        return $this.Config.CopyTheme($source)
    }

    # Le thème ôté — son fichier, par son nom.
    [void] DeleteTheme([string]$name) {
        $this.Config.DeleteTheme($name)
    }

    # Le fichier d'un thème ouvert comme Windows ouvre les fichiers — le
    # bouton crayon du Réglages.
    [void] OpenTheme([string]$name) {
        $this.Config.OpenTheme($name)
    }

    # Un thème rendu où l'utilisateur pointe — la source est passée entière :
    # le fichier du thème, ou, pour « Default », le chart que la fenêtre
    # connaît.
    [void] ExportTheme([ExportThemeDto]$dto) {
        Copy-Item -LiteralPath $dto.Source -Destination $dto.Target -Force -ErrorAction Stop
    }

    # Les familles que la fenêtre peut porter : celles du dossier des polices
    # d'abord, celles que la machine porte en dernier — une famille déjà
    # offerte par le dossier n'est pas offerte deux fois.
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
