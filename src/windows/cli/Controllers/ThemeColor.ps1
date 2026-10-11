# The theme_color's conversation: the instance (asked here, or handed by the
# theme menu), the fragment warning, and the schemes asked again and again -
# one visit is any number of picks, Escape leaves. The picks travel whole, in
# order, and the command applies them: nothing is written here, so a visit
# abandoned at the end changes nothing.
using module ..\..\WslModel\WslModel.psd1

function Read-ThemeColorAnswers {
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
        Write-Host "        Run it on its own:  .\wsl.ps1 theme_color" -ForegroundColor (Get-MessageColour hint)
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

    Clear-MenuScreen

    # Worth saying before the question because it is what would make all of it
    # invisible: a scheme is only ever read through the fragment this
    # repository writes.
    $OurFragment = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\wsl-stack\$DistroName.json"
    if (-not (Test-Path $OurFragment)) {
        Write-Host ""
        Write-Host "[WARNING] This instance has no Terminal profile of ours - the colours would not show." -ForegroundColor (Get-MessageColour warning)
        Write-Host "          Build it again, or set them by hand in Ctrl+," -ForegroundColor (Get-MessageColour muted)
    }

    # The escape character, and whether colours are worth writing: the second
    # from WslUI.ps1, where it is written once for every command that shows a
    # colour.
    $Escape = [char]27
    $Coloured = Test-ColourOutput

    # The list is every scheme this machine can be told to use: those Terminal
    # ships and those the user added or wrote over. Its walk that knows what a
    # string is lives in the message module, once.
    Write-Host ""
    Write-Host "Reading the colour schemes Windows Terminal has..." -ForegroundColor (Get-MessageColour muted)

    $Schemes = Get-ColorSchemes
    if ($Schemes.Count -eq 0) {
        Write-Host ""
        Write-Host "[ABORT] No colour scheme could be read on this machine." -ForegroundColor (Get-MessageColour error)
        Write-Host "        Nothing was modified." -ForegroundColor (Get-MessageColour muted)
        return $null
    }
    $Names = @($Schemes.Keys | Sort-Object)

    # 2. The list, again and again: the scheme in use is the profile's - or
    # the last pick, since nothing is applied before the visit is over. The
    # row text is painted here, escapes and all - the label reads nothing from
    # around itself.
    $Picks = @()
    $Default = 0
    while ($true) {
        $Current = if ($Picks.Count -gt 0) { $Picks[-1] } else { $Manager.AppearanceOf($Distro).ColorScheme }

        $Rows = @($Names | ForEach-Object {
            $Name = $_
            $Scheme = $Schemes[$Name]

            # Padded, and padded INSIDE the colours: every row has to end at
            # the same column, or the painted blocks come out raggeder the
            # longer the names get. The mark gets a column of its own for the
            # same reason.
            $Here = if ($Name -eq $Current) { "(current)" } else { "" }
            $Text = "{0,-20} {1,-11}" -f $Name, $Here

            # The mark in red, found before the row is read - and the colour
            # goes around the word INSIDE the padded text: padding a string
            # that carries escapes would count them as letters and break the
            # column.
            if ($Here -and $Coloured) {
                $Text = $Text -replace [regex]::Escape($Here), ("{0}[91m{1}{0}[39m" -f $Escape, $Here)
            }
            $Sample = $Text

            # The scheme itself, painted: what is being chosen is a look, and
            # a name says nothing to the eye.
            #
            # The reset comes first: a label cut by a narrow window would
            # otherwise leave the terminal wearing the colours of the row it
            # was cut in.
            if ($Coloured -and $Scheme -and $Scheme.background -and $Scheme.foreground) {
                $Sample = "{0}[0m{0}[48;2;{1}m{0}[38;2;{2}m{3}{0}[0m" -f $Escape,
                    (ConvertTo-Rgb $Scheme.background), (ConvertTo-Rgb $Scheme.foreground), $Text
            }

            # And nothing else: the painted row is the whole preview.
            @{ Name = $Name; Text = $Sample }
        })

        $Picked = Select-FromList -Title "Colours of '$DistroName'" -Items $Rows -Label {
            param($Row) $Row.Text
        } -DefaultIndex $Default

        if (-not $Picked) { break }

        # The menu has been answered: the screen goes clean, and the answer
        # takes its place - then the screen again, so the list comes back on
        # its own.
        Clear-MenuScreen

        $Default = [array]::IndexOf($Names, $Picked.Name)
        $Picks += $Picked.Name

        Clear-MenuScreen
    }

    Clear-MenuScreen

    # Nothing picked and the visit over: handed over, the level above owns the
    # goodbye; on its own, cancelling is said once.
    if ($Picks.Count -eq 0) {
        if ($HandedOver) { return $null }
        Stop-Cancelled
    }

    return [PSCustomObject]@{ Instance = $Distro; Schemes = @($Picks) }
}
