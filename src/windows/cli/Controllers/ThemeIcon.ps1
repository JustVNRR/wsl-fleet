# The theme_icon's conversation: the instance (asked here, or handed by the
# theme menu), the fragment warning, and the icon's menu asked again and
# again - one visit is any number of changes, Escape leaves. Each turn is
# settled by the drawing script itself, to a file of ours, so the turns read
# back what the command will really draw - and nothing of the instance's is
# written before the visit is over: what comes back is the whole decision,
# an image of your own or the settled recipe, and the command applies it.
using module ..\..\WslModel\WslModel.psd1

# One turn of the menu: what the choice needs, asked here. Answers the
# decision - or $null when the turn was left behind (Escape on the colours
# list, an empty answer with nothing to suggest): the decisions before it
# stand.
function Read-IconDecision {
    param(
        [hashtable]$Choice,
        [hashtable]$Known,
        [string]$Suggestion,
        [string]$DistroName,
        [string]$IconScript,
        [string]$Escape,
        [bool]$Coloured
    )

    switch ($Choice.How) {
        "auto" { return @{ How = "auto" } }

        "letters" {
            # Up to three: a tab is about sixteen pixels tall, and past three
            # letters stop being letters.
            $Question = if ($Suggestion) { "Letters, 1 to 3 [$Suggestion]" } else { "Letters, 1 to 3" }
            while ($true) {
                Write-Host -NoNewline "${Question}: "
                $Answer = [string](Read-Host).Trim()
                # Enter takes what is suggested - the letters the icon has
                # now, or the name's. With nothing to suggest it leaves the
                # turn behind.
                if ([string]::IsNullOrWhiteSpace($Answer)) {
                    if (-not $Suggestion) { return $null }
                    return @{ How = "letters"; Text = $Suggestion }
                }
                if ($Answer -match '^[A-Za-z0-9]{1,3}$') {
                    return @{ How = "letters"; Text = $Answer.ToUpper() }
                }
                Write-Host "  One to three letters or digits." -ForegroundColor (Get-MessageColour hint)
            }
        }

        "colours" {
            # Every pair shown with the letters in hand: two hex codes say
            # nothing to the eye, and the letters are what the pair is for.
            # The row text is built here, escapes and all - the label reads
            # nothing from around itself.
            $Rows = @(& $IconScript -ListPairs | Where-Object { $_ } | ForEach-Object {
                $Field = $_ -split "`t"
                $Sample = $Suggestion
                if ($Coloured) {
                    $Ink = if ($Field[3] -eq "#FFFFFF") { "97" } else { "30" }
                    $Sample = "{0}[48;2;{1}m{0}[{2}m {3} {0}[0m" -f $Escape, (ConvertTo-Rgb $Field[1]), $Ink, $Suggestion
                }
                # The pair the icon is on now - choosing is easier when you
                # know where you are.
                $Here = if ($Known.Top -eq $Field[1] -and $Known.Bottom -eq $Field[2]) { "  (current)" } else { "" }
                @{ Row = $_; Text = "{0}  {1,-9}{2}" -f $Sample, $Field[0], $Here }
            })
            $Picked = Select-FromList -Title "Colours for '$DistroName'" -Items $Rows -Label {
                param($Choice) $Choice.Text
            }
            if (-not $Picked) { return $null }
            $Field = $Picked.Row -split "`t"
            return @{ How = "colours"; Top = $Field[1]; Bottom = $Field[2]; TextColor = $Field[3] }
        }

        "image" {
            while ($true) {
                $Answer = (Read-Answer "Path of the image, PNG JPG ICO or BMP (CTRL+C to abort)").Trim('"')
                if (-not (Test-Path -LiteralPath $Answer -PathType Leaf)) {
                    Write-Host "  No file at that path." -ForegroundColor (Get-MessageColour warning)
                    continue
                }
                if ((Split-Path -Leaf $Answer) -notmatch '\.(png|jpg|jpeg|ico|bmp)$') {
                    Write-Host "  The name has to end in .png, .jpg, .jpeg, .ico or .bmp." -ForegroundColor (Get-MessageColour hint)
                    continue
                }
                return @{ How = "image"; Path = (Resolve-Path -LiteralPath $Answer).Path }
            }
        }
    }
}

function Read-ThemeIconAnswers {
    param(
        [WslInstanceManager]$Manager,

        # The instance, when the theme menu has already asked which one: how
        # the level above hands over. Empty when the command is run on its
        # own, and the list is asked here.
        [string]$DistroName = "",

        # What was typed after the command, untouched. The vocabulary is
        # empty: any word stops the run before a single question.
        [object[]]$Options = @()
    )

    # The words, paired up - the same reading the other conversations do:
    # a glued '-Name:value' is taken whole, and a word with no dash is kept
    # as an option named itself, so it lands in the refusal.
    $Typed = @{}
    $Pending = ""
    foreach ($Word in @($Options)) {
        $Word = "$Word"
        if ($Word.StartsWith('-')) {
            $Rest = $Word.TrimStart('-')
            $Cut = $Rest.IndexOf(':')
            if ($Cut -ge 0) {
                $Pending = $Rest.Substring(0, $Cut)
                $Glued = $Rest.Substring($Cut + 1)
                if ($Glued) { $Typed[$Pending] = $Glued; $Pending = "" }
                elseif (-not $Typed.ContainsKey($Pending)) { $Typed[$Pending] = "" }
            } else {
                $Pending = $Rest
                if (-not $Typed.ContainsKey($Pending)) { $Typed[$Pending] = "" }
            }
            continue
        }
        if ($Pending) { $Typed[$Pending] = $Word; $Pending = "" }
        else { $Typed[$Word] = "" }
    }
    foreach ($Option in @($Typed.Keys)) {
        Write-Host ""
        Write-Host "[ABORT] Unknown options after the command." -ForegroundColor (Get-MessageColour error)
        Write-Host "        Run it on its own:  .\wsl.ps1 theme_icon" -ForegroundColor (Get-MessageColour hint)
        return $null
    }

    # 1. Which instance - handed by the theme menu, or asked.
    $HandedOver = [bool]$DistroName
    if ($HandedOver) {
        $Distro = $Manager.FindByName($DistroName)
        if (-not $Distro) {
            Write-Host ""
            Write-Host "[ABORT] No instance named '$DistroName' is registered here." -ForegroundColor (Get-MessageColour error)
            return $null
        }
    } else {
        $Distro = Select-Distro -Manager $Manager
        $DistroName = $Distro.Name
    }

    # One script draws every icon, whether an instance is built or its icon is
    # redrawn years later: the letters and the colours cannot drift apart.
    $IconScript = Join-Path (Split-Path -Path $PSScriptRoot -Parent) "..\make-icon.ps1"
    if (-not (Test-Path $IconScript)) {
        Write-Host ""
        Write-Host "[ABORT] src\windows\make-icon.ps1 is missing - the checkout is incomplete." -ForegroundColor (Get-MessageColour error)
        Write-Host "        Nothing was modified." -ForegroundColor (Get-MessageColour muted)
        return $null
    }

    # The menus it came through come off the screen: a visit of four turns is
    # one screen, not four stacked menus.
    Clear-MenuScreen

    # Worth saying before the question because it is what would make all of it
    # invisible: an icon is only ever read through the fragment this repository
    # writes.
    $OurFragment = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\wsl-stack\$DistroName.json"
    if (-not (Test-Path $OurFragment)) {
        Write-Host ""
        Write-Host "[WARNING] This instance has no Terminal profile of ours - the icon would not show." -ForegroundColor (Get-MessageColour warning)
        Write-Host "          Build it again, or set the icon by hand in Ctrl+," -ForegroundColor (Get-MessageColour muted)
    }

    # The escape character, and whether colours are worth writing: the second
    # from WslUI.ps1, where it is written once for every command that shows a
    # colour.
    $Escape = [char]27
    $Coloured = Test-ColourOutput

    # 2. The question, again and again. The recipe is what carries the turns:
    # each drawing decision is settled by the drawing script to a file of
    # ours, and the next turn starts from what it settled - one change keeps
    # the others. An image wins if it came last: it replaces the picture, not
    # the drawing behind it.
    $Choices = @(
        @{ What = "By Default"; How = "auto" },
        @{ What = "text";       How = "letters" },
        @{ What = "colors";     How = "colours" },
        @{ What = "local file"; How = "image" }
    )

    $Known = $Manager.IconRecipeOf($Distro)
    $Image = ""
    $Default = 0
    $Decided = $false

    while ($true) {
        # Every turn: the questions offer what the icon is made of now - the
        # recipe just settled, or the one the instance carries.
        $Suggested = $Known.Text
        if (-not $Suggested) {
            $Suggested = [string](@(& $IconScript -Letters -Name $DistroName | Select-Object -First 1)[0])
        }

        Write-Host ""
        $Chosen = Select-FromList -Title "Icon of '$DistroName'" -Items $Choices -Label {
            param($Choice) $Choice.What
        } -DefaultIndex $Default

        if (-not $Chosen) { break }

        # The menu has been answered: the screen goes clean, and the answer
        # takes its place - then the screen again, so the menu comes back on
        # its own.
        Clear-MenuScreen

        # The same place next time: two changes are one visit.
        $Default = [array]::IndexOf($Choices, $Chosen)

        $Decision = Read-IconDecision -Choice $Chosen -Known $Known -Suggestion $Suggested `
            -DistroName $DistroName -IconScript $IconScript -Escape $Escape -Coloured $Coloured
        if ($null -eq $Decision) { break }

        if ($Decision.How -eq "image") {
            $Image = $Decision.Path
            $Decided = $true
        } else {
            # What the drawing script is told, by name: the recipe in hand,
            # then the part just decided - so only that part moves. A
            # hashtable, not a list: handed a LIST the script reads its values
            # in order, not by name. The automatic one starts over from the
            # name - the kept letters and colours go with it.
            if ($Decision.How -eq "auto") {
                $Draw = @{ Name = $DistroName }
            } else {
                $Draw = @{ Name = $DistroName }
                $Draw += $Known
                if ($Decision.How -eq "letters") { $Draw.Text = $Decision.Text }
                else { $Draw.Top = $Decision.Top; $Draw.Bottom = $Decision.Bottom; $Draw.TextColor = $Decision.TextColor }
            }

            # Settled by the drawing script itself, to a file of ours: this is
            # exactly what the command will draw for real, and what the next
            # turns read back. A drawing that fails is said once, and the
            # visit keeps what it had.
            $Scratch = Join-Path ([IO.Path]::GetTempPath()) ("wsl-stack-icon-" + [guid]::NewGuid().ToString("N") + ".png")
            try {
                $Drawn = & $IconScript @Draw -Out $Scratch -Quiet -What | ConvertFrom-Json
            } catch {
                Write-Host ""
                Write-Host "[ABORT] The icon could not be drawn: $($_.Exception.Message)" -ForegroundColor (Get-MessageColour error)
                Write-Host "        The icon that was there is still there." -ForegroundColor (Get-MessageColour muted)
                break
            } finally {
                Remove-Item -LiteralPath $Scratch -Force -ErrorAction SilentlyContinue
            }
            $Known = @{ Text = $Drawn.Text; Top = $Drawn.Top; Bottom = $Drawn.Bottom; TextColor = $Drawn.TextColor }
            $Image = ""
            $Decided = $true
        }

        Clear-MenuScreen
    }

    Clear-MenuScreen

    # Nothing decided and the visit over: handed over, the level above owns
    # the goodbye; on its own, cancelling is said once.
    if (-not $Decided) {
        if ($HandedOver) { return $null }
        Stop-Cancelled
    }

    return [PSCustomObject]@{ Instance = $Distro; Image = $Image; Recipe = $Known }
}
