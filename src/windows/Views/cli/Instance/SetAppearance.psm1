# ==============================================================================
# SETAPPEARANCE — LA VUE DU CLI
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewCli.psm1
using module ..\..\..\Dto\InstanceDto.psm1

# La visite du look, en une vue : le menu des trois — icon, font, color — et
# chaque choix ouvre sa conversation, qui redemande jusqu'à Échap. Tout
# s'accumule, et Ask rend le SetAppearanceDto entier : un seul appel au
# service, à la sortie. Échap au menu termine la visite — une visite = une
# instance (la liste est la vue SelectInstance, en amont).
class CliSetAppearanceView : BaseViewCli {
    [object] Ask([string]$name, [object]$appearance, [string[]]$fonts, [object[]]$schemes, [object[]]$pairs) {
        # L'avertissement d'avant, avant les questions : c'est ce qui rendrait
        # tout invisible — le look ne se lit qu'à travers notre fragment.
        if (-not $appearance.HasFragment) {
            Write-Host ""
            Write-Host "[WARNING] This instance has no Terminal profile of ours - the look would not show." -ForegroundColor $this.Colour("warning")
            Write-Host "          Build it again, or set it by hand in Ctrl+," -ForegroundColor $this.Colour("muted")
        }

        $dto = [SetAppearanceDto]::new()
        $dto.InstanceName = $name

        # La recette en main entre les tours : ce que la tuile est en train de
        # devenir — le dessin affiché, puis chaque décision, une change un
        # champ et les autres ne bougent pas.
        $recipe = [WslIconDto]::new()
        if ($appearance.Icon) {
            $recipe.Text = "$($appearance.Icon.Text)"
            $recipe.Top = "$($appearance.Icon.Top)"
            $recipe.Bottom = "$($appearance.Icon.Bottom)"
            $recipe.TextColor = "$($appearance.Icon.TextColor)"
        }

        $choices = @(
            @{ What = "icon";  About = "the tile in the tab" },
            @{ What = "font";  About = "what the whole terminal is written in" },
            @{ What = "color"; About = "the background, the text, and sixteen colours" }
        )

        $decided = $false
        while ($true) {
            $this.ClearScreen()
            $chosen = $this.AskList("Theme of '$name'", $choices, { param($choice) "{0,-6} {1}" -f $choice.What, $choice.About }, "")
            if ($null -eq $chosen) { break }

            $this.ClearScreen()
            if ($chosen.What -eq "font") {
                if ($this.AskFont($dto, $appearance, $fonts)) { $decided = $true }
            } elseif ($chosen.What -eq "color") {
                if ($this.AskColour($dto, $appearance, $schemes)) { $decided = $true }
            } else {
                if ($this.AskIcon($dto, $recipe, $pairs)) { $decided = $true }
            }
        }

        $this.ClearScreen()
        if (-not $decided) { return $null }
        return $dto
    }

    # La conversation de la police : la liste encore et encore, chaque choix
    # remplace le précédent, Échap revient au menu du thème.
    hidden [bool] AskFont([SetAppearanceDto]$dto, [object]$appearance, [string[]]$fonts) {
        $current = "$($appearance.Font)"
        $decided = $false
        while ($true) {
            $this.ClearScreen()
            $rows = @($fonts | ForEach-Object {
                $here = if ($_ -eq $current) { "(current)" } else { "" }
                [PSCustomObject]@{ Name = "$_"; Text = "{0,-33} {1}" -f "$_", $here }
            })
            $picked = $this.AskList("Font of '$($dto.InstanceName)'", $rows, { param($row) $row.Text }, "Get more Nerd Fonts at https://www.nerdfonts.com")
            if ($null -eq $picked) { break }
            $dto.Font = "$($picked.Name)"
            $current = "$($picked.Name)"
            $decided = $true
        }
        return $decided
    }

    # La conversation des couleurs : chaque ligne est peinte du schéma qu'elle
    # nomme — ce qui se choisit est un look, et un nom ne dit rien à l'œil.
    hidden [bool] AskColour([SetAppearanceDto]$dto, [object]$appearance, [object[]]$schemes) {
        $escape = [char]27
        $coloured = $this.ColourOutput()
        $current = "$($appearance.ColourScheme)"
        $decided = $false
        while ($true) {
            $this.ClearScreen()
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
            $picked = $this.AskList("Colours of '$($dto.InstanceName)'", $rows, { param($row) $row.Text }, "")
            if ($null -eq $picked) { break }
            $dto.ColourScheme = "$($picked.Name)"
            $current = "$($picked.Name)"
            $decided = $true
        }
        return $decided
    }

    # La conversation de la tuile : le menu des quatre, chaque tour gardé dans
    # la recette. Un tour de dessin efface l'image ; l'image prend le siège et
    # le dessin reste derrière — c'est l'ordre des tours qui compte, comme
    # avant.
    hidden [bool] AskIcon([SetAppearanceDto]$dto, [WslIconDto]$recipe, [object[]]$pairs) {
        $escape = [char]27
        $coloured = $this.ColourOutput()

        $choices = @(
            @{ What = "By Default"; How = "auto" },
            @{ What = "text";       How = "letters" },
            @{ What = "colors";     How = "colours" },
            @{ What = "local file"; How = "image" }
        )

        $decided = $false
        while ($true) {
            $this.ClearScreen()
            $chosen = $this.AskList("Icon of '$($dto.InstanceName)'", $choices, { param($choice) $choice.What }, "")
            if ($null -eq $chosen) { break }

            $this.ClearScreen()
            if ($chosen.How -eq "auto") {
                # Le dessin par défaut : des champs vides — make-icon remplira
                # les lettres et les couleurs du nom, au moment d'appliquer.
                $recipe.Text = ""; $recipe.Top = ""; $recipe.Bottom = ""; $recipe.TextColor = ""
                $dto.Icon = $this.CopyRecipe($recipe)
                $dto.IconImage = ""
                $decided = $true
            } elseif ($chosen.How -eq "letters") {
                $suggestion = "$($recipe.Text)"
                $question = if ($suggestion) { "Letters, 1 to 3 [$suggestion]" } else { "Letters, 1 to 3" }
                $settled = $false
                while ($true) {
                    Write-Host -NoNewline "${question}: "
                    $answer = [string](Read-Host).Trim()
                    if ([string]::IsNullOrWhiteSpace($answer)) {
                        # Entrée prend ce qui est suggéré ; sans suggestion,
                        # le tour est laissé.
                        if ($suggestion) { $recipe.Text = $suggestion.ToUpper(); $settled = $true }
                        break
                    }
                    if ($answer -match '^[A-Za-z0-9]{1,3}$') { $recipe.Text = $answer.ToUpper(); $settled = $true; break }
                    Write-Host "  One to three letters or digits." -ForegroundColor $this.Colour("hint")
                }
                if (-not $settled) { break }
                $dto.Icon = $this.CopyRecipe($recipe)
                $dto.IconImage = ""
                $decided = $true
            } elseif ($chosen.How -eq "colours") {
                # Chaque paire est montrée avec les lettres en main : deux
                # codes hexadécimaux ne disent rien à l'œil.
                $suggestion = "$($recipe.Text)"
                $rows = @($pairs | ForEach-Object {
                    $pair = $_
                    $sample = $suggestion
                    if ($coloured -and $suggestion) {
                        $ink = if ($pair.TextColor -eq "#FFFFFF") { "97" } else { "30" }
                        $sample = "{0}[48;2;{1}m{0}[{2}m {3} {0}[0m" -f $escape, $this.Rgb($pair.Top), $ink, $suggestion
                    }
                    $here = if ($pair.Top -eq $recipe.Top -and $pair.Bottom -eq $recipe.Bottom) { "  (current)" } else { "" }
                    [PSCustomObject]@{ Pair = $pair; Text = "{0}  {1,-9}{2}" -f $sample, $pair.Name, $here }
                })
                $picked = $this.AskList("Colours for '$($dto.InstanceName)'", $rows, { param($row) $row.Text }, "")
                if ($null -eq $picked) { break }
                $recipe.Top = "$($picked.Pair.Top)"
                $recipe.Bottom = "$($picked.Pair.Bottom)"
                $recipe.TextColor = "$($picked.Pair.TextColor)"
                $dto.Icon = $this.CopyRecipe($recipe)
                $dto.IconImage = ""
                $decided = $true
            } else {
                $settled = $false
                while ($true) {
                    $answer = [string](Read-Host "Path of the image, PNG JPG ICO or BMP (CTRL+C to abort)").Trim('"')
                    if (-not (Test-Path -LiteralPath $answer -PathType Leaf)) {
                        Write-Host "  No file at that path." -ForegroundColor $this.Colour("warning")
                        continue
                    }
                    if ((Split-Path -Leaf $answer) -notmatch '\.(png|jpg|jpeg|ico|bmp)$') {
                        Write-Host "  The name has to end in .png, .jpg, .jpeg, .ico or .bmp." -ForegroundColor $this.Colour("hint")
                        continue
                    }
                    $dto.IconImage = (Resolve-Path -LiteralPath $answer).Path
                    $settled = $true
                    break
                }
                if ($settled) { $decided = $true }
            }
        }
        return $decided
    }

    # La recette copiée dans le Dto : le Dto part au service, la recette
    # locale continue la visite.
    hidden [WslIconDto] CopyRecipe([WslIconDto]$recipe) {
        $dto = [WslIconDto]::new()
        $dto.Text = $recipe.Text
        $dto.Top = $recipe.Top
        $dto.Bottom = $recipe.Bottom
        $dto.TextColor = $recipe.TextColor
        return $dto
    }

    # Le rapport : les changements, dans les mots du service.
    [void] Show([string]$name, [object]$response) {
        Write-Host ""
        Write-Host "==> Theme of '$name': $(@($response) -join ', ')" -ForegroundColor $this.Colour("success")
        Write-Host ""
    }
}
