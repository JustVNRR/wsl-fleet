# ==============================================================================
# SETAPPEARANCE — LA VUE DU CLI
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewCli.psm1

# La visite du look, en une vue : la vue ne décide plus — les boucles, les
# règles et la recette vivent au presenter. Ici, les menus du thème et de
# chaque choix, la ligne du dessin et les questions — chacune rend la réponse
# brute, vide quand on sort. Échap au menu du thème termine la visite.
class CliSetAppearanceView : BaseViewCli {
    # L'avertissement d'avant, avant les questions : c'est ce qui rendrait
    # tout invisible — le look ne se lit qu'à travers notre fragment.
    [void] ShowNoFragmentWarning() {
        Write-Host ""
        Write-Host "[WARNING] This instance has no Terminal profile of ours - the look would not show." -ForegroundColor $this.Colour("warning")
        Write-Host "          Build it again, or set it by hand in Ctrl+," -ForegroundColor $this.Colour("muted")
    }

    # Le menu des trois. Vide quand on sort — le presenter le lit comme la fin
    # de la visite.
    [string] AskTheme([string]$name) {
        $choices = @(
            @{ What = "icon";  About = "the tile in the tab" },
            @{ What = "font";  About = "what the whole terminal is written in" },
            @{ What = "color"; About = "the background, the text, and sixteen colours" }
        )
        $chosen = $this.AskList("Theme of '$name'", $choices, { param($choice) "{0,-6} {1}" -f $choice.What, $choice.About }, "")
        if ($null -eq $chosen) { return "" }
        return "$($chosen.What)"
    }

    # La question de la police : la liste reçue, la ligne en place marquée.
    # Vide quand on sort.
    [string] AskFont([string]$name, [string[]]$fonts, [string]$current) {
        $rows = @($fonts | ForEach-Object {
            $here = if ($_ -eq $current) { "(current)" } else { "" }
            [PSCustomObject]@{ Name = "$_"; Text = "{0,-33} {1}" -f "$_", $here }
        })
        $picked = $this.AskList("Font of '$name'", $rows, { param($row) $row.Text }, "Get more Nerd Fonts at https://www.nerdfonts.com")
        if ($null -eq $picked) { return "" }
        return "$($picked.Name)"
    }

    # La question des couleurs : chaque ligne est peinte du schéma qu'elle
    # nomme — ce qui se choisit est un look, et un nom ne dit rien à l'œil.
    # Vide quand on sort.
    [string] AskColour([string]$name, [object[]]$schemes, [string]$current) {
        $escape = [char]27
        $coloured = $this.ColourOutput()
        $rows = @($schemes | Sort-Object Name | ForEach-Object {
            $scheme = $_
            $here = if ($scheme.Name -eq $current) { "(current)" } else { "" }
            $text = "{0,-20} {1,-11}" -f $scheme.Name, $here
            if ($here -and $coloured) {
                $text = $text -replace [regex]::Escape($here), ("{0}[91m{1}{0}[39m" -f $escape, $here)
            }
            $sample = $text
            # Le reset d'abord : une ligne coupée par une fenêtre étroite
            # ne doit pas laisser le terminal porter ses couleurs.
            if ($coloured -and $scheme.Background -and $scheme.Foreground) {
                $sample = "{0}[0m{0}[48;2;{1}m{0}[38;2;{2}m{3}{0}[0m" -f $escape, $this.Rgb($scheme.Background), $this.Rgb($scheme.Foreground), $text
            }
            [PSCustomObject]@{ Name = "$($scheme.Name)"; Text = $sample }
        })
        $picked = $this.AskList("Colours of '$name'", $rows, { param($row) $row.Text }, "")
        if ($null -eq $picked) { return "" }
        return "$($picked.Name)"
    }

    # Le menu des quatre de la tuile. Vide quand on sort ; sinon le mot du
    # choix — ce que chaque tour veut dire reste au presenter.
    [string] AskIconType([string]$name) {
        $choices = @(
            @{ What = "By Default"; How = "auto" },
            @{ What = "text";       How = "letters" },
            @{ What = "colors";     How = "colours" },
            @{ What = "local file"; How = "image" }
        )
        $chosen = $this.AskList("Icon of '$name'", $choices, { param($choice) $choice.What }, "")
        if ($null -eq $chosen) { return "" }
        return "$($chosen.How)"
    }

    # Les lettres, lues — la question et rien d'autre : ce qu'un vide ou une
    # forme refusée veulent dire reste au presenter.
    [string] AskLetters([string]$question) {
        Write-Host -NoNewline "${question}: "
        return [string](Read-Host).Trim()
    }

    [void] ShowLettersHint() {
        Write-Host "  One to three letters or digits." -ForegroundColor $this.Colour("hint")
    }

    # La question des paires : chaque paire est montrée avec les lettres en
    # main — deux codes hexadécimaux ne disent rien à l'œil. Rendue, la paire
    # choisie ; rien quand on sort.
    [object] AskIconPair([string]$name, [object[]]$pairs, [string]$suggestion, [string]$currentTop, [string]$currentBottom) {
        $escape = [char]27
        $coloured = $this.ColourOutput()
        $rows = @($pairs | ForEach-Object {
            $pair = $_
            $sample = $suggestion
            if ($coloured -and $suggestion) {
                $ink = if ($pair.TextColor -eq "#FFFFFF") { "97" } else { "30" }
                $sample = "{0}[48;2;{1}m{0}[{2}m {3} {0}[0m" -f $escape, $this.Rgb($pair.Top), $ink, $suggestion
            }
            $here = if ($pair.Top -eq $currentTop -and $pair.Bottom -eq $currentBottom) { "  (current)" } else { "" }
            [PSCustomObject]@{ Pair = $pair; Text = "{0}  {1,-9}{2}" -f $sample, $pair.Name, $here }
        })
        $picked = $this.AskList("Colours for '$name'", $rows, { param($row) $row.Text }, "")
        if ($null -eq $picked) { return "" }
        return $picked.Pair
    }

    # Le chemin de l'image, lu — la question et rien d'autre : l'existence du
    # fichier et sa forme restent au presenter.
    [string] AskImagePath() {
        return [string](Read-Host "Path of the image, PNG JPG ICO or BMP (CTRL+C to abort)").Trim('"')
    }

    [void] ShowNoFile() {
        Write-Host "  No file at that path." -ForegroundColor $this.Colour("warning")
    }

    [void] ShowBadExtension() {
        Write-Host "  The name has to end in .png, .jpg, .jpeg, .ico or .bmp." -ForegroundColor $this.Colour("hint")
    }

    # Le rapport : les changements, dans les mots du service.
    [void] Show([object]$response) {
        Write-Host ""
        Write-Host "==> Theme of '$($response.InstanceName)': $(@($response.Changes) -join ', ')" -ForegroundColor $this.Colour("success")
        Write-Host ""
    }
}
