# ==============================================================================
# LA VUE DU CLI — LA BASE
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module .\MenuCli.psm1
using module .\ThemeCli.psm1

# L'appareil du cli, en une classe : ce que les vues partagent — afficher une
# liste et lire le choix, poser une question et lire la réponse, les portes
# de confirmation, les couleurs, l'écran qu'on efface, et les deux fins d'une
# question (annulée, ou rien à faire). Chaque vue EN HÉRITE : elle porte son
# Ask et son Show, l'appareil dessous. La question « quelle instance ? » est
# une vue à part (SelectInstance), elle aussi sur cette base.
#
# La vue ne connaît PAS le service : le contrôleur fait toutes les lectures,
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
        # La virgule : la sortie d'une méthode est déroulée, et « rien coché »
        # doit arriver comme une liste vide, pas comme rien du tout.
        return ,@($Picked | ForEach-Object { $_.Value })
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

    # La porte de toute destruction : la bannière, la phrase qui dit laquelle,
    # le nom exact retapé. Rend si le nom fut retapé ; ce qu'un non veut dire
    # reste à l'appelant.
    [bool] ConfirmDestruction([string]$name, [string]$lead) {
        [Console]::Beep(1000, 400)
        Write-Host ""
        $this.ShowDangerBanner("DANGER: TOTAL DATA LOSS IMMINENT")
        Write-Host ""
        Write-Host "  $lead" -ForegroundColor $this.Colour("error")
        Write-Host ""
        Write-Host "  Proceeding will PERMANENTLY DESTROY this distribution:" -ForegroundColor $this.Colour("warning")
        Write-Host "    - Executing: wsl --unregister $name" -ForegroundColor $this.Colour("muted")
        Write-Host "    - IRREVERSIBLE DELETION of the virtual disk (VHDX)" -ForegroundColor $this.Colour("muted")
        Write-Host "    - TOTAL LOSS of projects, SSH keys, and all files in /home" -ForegroundColor $this.Colour("muted")
        Write-Host ""
        Write-Host "  THIS OPERATION CANNOT BE UNDONE." -ForegroundColor $this.Colour("error")
        Write-Host ""
        Write-Host " ----------------------------------------------------------------------" -ForegroundColor $this.Colour("muted")
        Write-Host " Press ENTER to abort immediately." -ForegroundColor $this.Colour("hint")
        Write-Host " To confirm DESTRUCTION, type the exact name of the distribution:" -ForegroundColor $this.Colour("hint")
        $Confirmation = Read-Host " Confirm"
        Write-Host " ----------------------------------------------------------------------" -ForegroundColor $this.Colour("muted")
        Write-Host ""

        # -ceq, pas -eq : -eq ignore la casse, et la bannière demande le nom
        # exact — c'est le nom retapé qui compte, pas un Entrée réflexe.
        return ($Confirmation -ceq $name)
    }

    # Une réponse tapée, son vide une annulation comme une autre : la question
    # s'écrit ici et Read-Host est demandé nu — ce que Read-Host écrit
    # lui-même n'atteint jamais un pipe.
    [string] AskAnswer([string]$question, [string]$what) {
        Write-Host -NoNewline "${question}: "
        $Answer = [string](Read-Host).Trim()
        if ([string]::IsNullOrWhiteSpace($Answer)) { $this.StopCancelled($what) }
        return $Answer
    }

    # Un nom d'instance, demandé jusqu'à ce qu'il en soit un : la forme
    # vérifiée, l'indice de refus montré, le vide qui annule.
    [string] AskName([string]$question, [string]$what) {
        while ($true) {
            $Answer = [string](Read-Host $question)
            if ([string]::IsNullOrWhiteSpace($Answer)) { $this.StopCancelled($what) }
            $Answer = $Answer.Trim()
            if ($Answer -match '^[A-Za-z0-9][A-Za-z0-9_.-]*$') { return $Answer }
            Write-Host "  Letters, digits, '.', '_' and '-' only." -ForegroundColor $this.Colour("hint")
        }

        # Jamais atteint — la boucle ne sort qu'en rendant ou en annulant ;
        # pour l'analyseur, qui ne sait pas le prouver.
        return ""
    }

    # --- les deux fins d'une question -----------------------------------------

    # L'annulation partagée : une ligne vide, le mot de ce qui n'a PAS été
    # touché, et la course s'arrête ici.
    [void] StopCancelled([string]$what) {
        Write-Host ""
        Write-Host "[ABORT] Operation cancelled by user. Nothing was $what." -ForegroundColor $this.Colour("success")
        exit 0
    }

    # Rien à faire, ou rien à demander : la première ligne est le refus, les
    # suivantes sont ses repères — et la course s'arrête ici, en faute.
    [void] Abort([string[]]$lines) {
        Write-Host ""
        $first = $true
        foreach ($line in @($lines)) {
            if ($first) {
                Write-Host "[ABORT] $line" -ForegroundColor $this.Colour("error")
                $first = $false
            } else {
                Write-Host "        $line" -ForegroundColor $this.Colour("hint")
            }
        }
        exit 1
    }
}
