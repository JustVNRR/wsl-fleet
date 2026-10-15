# ==============================================================================
# LA VUE DU CLI — LA BASE
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module .\MenuCli.psm1
using module .\ThemeCli.psm1

# L'appareil du cli, en une classe : ce que les vues partagent — afficher une
# liste et lire le choix, poser une question et lire la réponse, les portes
# de confirmation, les couleurs, l'écran qu'on efface, et l'annulation
# AFFICHÉE. Chaque vue EN HÉRITE : elle peint et lit, l'appareil dessous —
# aucune vue ne coupe la course : la seule sortie est l'ActionResult du
# geste, à l'entrée. La question « quelle instance ? » est une vue à part
# (SelectInstance), elle aussi sur cette base.
#
# La vue ne connaît PAS le service : le presenter fait toutes les lectures,
# et lui passe les données. La base est sans état : tout arrive en paramètre.
#
# Ce qui reste dehors pour l'instant : la science des couleurs elle-même
# (GetColor — ThemeCli.psm1), et l'appareil d'écran
# (MenuCli.psm1 — MenuCli, ConsoleCli, MenuItemCli), que la base s'en sert.
# Le suffixe Cli est là pour ça : aucun de ces noms ne masque un type .NET
# (mesuré : une classe Console ombrerait System.Console en silence) — le
# [Console] d'en dessous est donc bien le console .NET.
class BaseViewCli {
    BaseViewCli() {}

    # --- l'écran et ses couleurs ----------------------------------------------

    [object] Colour([string]$tone) {
        return [ThemeCli]::GetColor($tone)
    }

    [void] ClearScreen() {
        try { Clear-Host } catch { }
    }

    # Un clavier qu'on peut lire sans se figer — CursorTop et KeyAvailable
    # jettent sans console, et une exception est une réponse. $Host passe par
    # Get-Variable : dans une méthode de classe, le nom nu est refusé au
    # parse (mesuré).
    [bool] KeyInput() {
        if ([Console]::IsInputRedirected) { return $false }
        try {
            $console = Get-Variable -Name Host -ValueOnly
            $null = $console.UI.RawUI.KeyAvailable
            return $true
        } catch {
            return $false
        }
    }

    # "#CF7040" -> "207;112;64": comment un terminal écrit une couleur.
    [string] Rgb([string]$hex) {
        $Hex = $hex.TrimStart("#")
        return "{0};{1};{2}" -f [Convert]::ToInt32($Hex.Substring(0, 2), 16),
                               [Convert]::ToInt32($Hex.Substring(2, 2), 16),
                               [Convert]::ToInt32($Hex.Substring(4, 2), 16)
    }

    # Les couleurs ANSI valent-elles la peine d'être écrites : non quand la
    # sortie n'est pas un terminal, ou que NO_COLOR le dit.
    [bool] ColourOutput() {
        if ($env:NO_COLOR) { return $false }
        if ([Console]::IsOutputRedirected) { return $false }
        return $true
    }

    # --- afficher une question, lire la réponse -------------------------------

    # Une liste reçue, une réponse — $null quand l'utilisateur sort (Escape) :
    # ce que ça veut dire reste à l'appelant. $note s'écrit sous le bloc.
    [object] AskList([string]$title, [object[]]$items, [scriptblock]$label, [string]$note) {
        $Items = @($items)
        if ($Items.Count -eq 0) { return $null }

        $Menu = [MenuCli]::new($title)
        $Menu.Note = $note
        foreach ($Item in $Items) {
            $null = $Menu.Add([MenuItemCli]::new([string](& $label $Item), $Item))
        }
        $Picked = $Menu.Prompt()

        if ($null -eq $Picked) { return $null }
        return $Picked.Value
    }

    # La même liste, à cocher — rend les valeurs cochées à la sortie du menu ;
    # $null quand l'utilisateur sort.
    [object[]] AskChecklist([string]$title, [object[]]$items, [scriptblock]$label, [int[]]$checkedIndexes, [string]$note) {
        $Items = @($items)
        if ($Items.Count -eq 0) { return @() }

        $Menu = [MenuCli]::new($title)
        foreach ($Item in $Items) {
            $null = $Menu.Add([MenuItemCli]::new([string](& $label $Item), $Item))
        }
        $Menu.Multi = $true
        $Menu.Note = $note
        foreach ($Index in @($checkedIndexes)) {
            if ($Index -ge 0 -and $Index -lt $Menu.Items.Count) { $Menu.Items[$Index].Checked = $true }
        }
        $Picked = $Menu.Prompt()

        if ($null -eq $Picked) { return $null }
        # Mesuré : sous un retour typé [object[]], la virgule d'autrefois
        # IMBRIQUAIT le tableau — le choix entier arrivait comme une seule
        # ligne. Un tableau plat sort déroulé ; rien coché sort une liste
        # vide, pas rien du tout — et l'Échap, lui, sort $null.
        return @($Picked | ForEach-Object { $_.Value })
    }

    # Un oui/non, la forme de toutes : [Y/n] quand oui est le défaut, [y/N]
    # quand c'est non. Ce que la réponse veut dire reste à l'appelant.
    [bool] Confirm([string]$question, [bool]$defaultNo) {
        $Shown = if ($defaultNo) { "$question [y/N]" } else { "$question [Y/n]" }
        $Answer = [string](Read-Host $Shown)
        if ($defaultNo) { return ($Answer -match "^[yY]") }
        return ($Answer -notmatch "^[nN]")
    }

    # La bannière de danger : le cadre et l'encre viennent de ThemeCli
    # (GetBannerColors — le rouge du thème quand il se lit, et la couleur
    # lisible posée dessus). Le texte est passé à chaque appel : un défaut de
    # paramètre n'existe pas pour une méthode de classe (mesuré — l'appel sans
    # argument jette).
    [void] ShowDangerBanner([string]$message) {
        $Colours = [ThemeCli]::GetBannerColors()

        Write-Host " /!\ ================================================================ /!\" -ForegroundColor $Colours.Ink -BackgroundColor $Colours.Box
        Write-Host (" |   {0,-60} |" -f $message) -ForegroundColor $Colours.Ink -BackgroundColor $Colours.Box
        Write-Host " \!/ ================================================================ \!/" -ForegroundColor $Colours.Ink -BackgroundColor $Colours.Box
    }

    # --- la fin d'une question -------------------------------------------------

    # L'annulation AFFICHÉE : le presenter a décidé, la vue dit les mots. Une
    # vue ne coupe jamais la course — la seule sortie est l'ActionResult du
    # geste, à l'entrée.
    [void] ShowCancelled([string]$what) {
        Write-Host ""
        Write-Host "[ABORT] Operation cancelled by user. Nothing was $what." -ForegroundColor $this.Colour("success")
    }
}
