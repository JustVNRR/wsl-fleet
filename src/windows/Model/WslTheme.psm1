# ==============================================================================
# L'APPARENCE D'UNE INSTANCE
# ==============================================================================
# Ce que Windows Terminal montre : icône, schéma de couleurs, police, titre de
# l'onglet — et la recette derrière une icône dessinée. Les champs sont hidden
# — cachés à l'IntelliSense, la discipline plutôt que le verrou — et la porte
# est la méthode : un couple Get/Set, la règle au Set. La forme seule : le
# fragment, le fichier et le registre Windows se lisent et s'écrivent au
# TerminalRepo.
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

    # --- Get/Set, la règle au Set ---------------------------------------------

    # L'icône portée : un seul siège — terminal-icon.png dans le dossier de
    # l'instance — dessinée, ou l'image d'un upload copiée dessus.
    [string] GetIconPath() { return $this.IconPath }
    [void] SetIconPath([string]$path) { $this.IconPath = $path }

    [string] GetColorScheme() { return $this.ColorScheme }
    [void] SetColourScheme([string]$scheme) { $this.ColorScheme = $scheme }

    [string] GetFontName() { return $this.FontName }
    [void] SetFont([string]$font) { $this.FontName = $font }

    [string] GetTabTitle() { return $this.TabTitle }
    [void] SetTabTitle([string]$title) { $this.TabTitle = $title }

    # Le dessin entier, par sa porte : le service change une part sans
    # fouiller l'objet (tell, don't ask), et une porte ne pose que la sienne —
    # un changement de police ou de couleur ne touche jamais le dessin.
    # L'image de l'utilisateur, elle, remplace le fichier (terminal-icon.png) :
    # rien du thème ne change, c'est le dépôt qui copie.
    [object] GetIcon() {
        return [PSCustomObject]@{
            Text      = $this.IconText
            Top       = $this.IconTop
            Bottom    = $this.IconBottom
            TextColor = $this.IconTextColor
        }
    }

    # Les couleurs du dessin gardent leur forme — #RRGGBB : un reste de clair
    # dans la recette est une couleur absente, pas une couleur fausse.
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

    # --------------------------------------------------------------------------

    # L'apparence avec laquelle toute instance naît : le couple du dépôt,
    # écrit ici une fois.
    static [WslTheme] Default([string]$tabTitle) {
        return [WslTheme]::new($null, "One Half Dark", "MesloLGS NF", $tabTitle)
    }

    [string] ToString() {
        return "font '$($this.FontName)', colours '$($this.ColorScheme)'"
    }
}
