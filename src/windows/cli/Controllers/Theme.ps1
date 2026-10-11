# The theme's conversation: the instance, the menu of the three commands, and
# the chosen command's own conversation, asked with the instance in hand - one
# visit is any number of runs, Escape walks back up. The runs are collected
# whole, in order, and the command replays them: nothing is written here, so a
# visit abandoned at the end changes nothing.
using module ..\..\WslModel\WslModel.psd1

# The three child conversations, mounted here: this one asks their questions
# at the level they are chosen from.
. (Join-Path $PSScriptRoot "ThemeIcon.ps1")
. (Join-Path $PSScriptRoot "ThemeFont.ps1")
. (Join-Path $PSScriptRoot "ThemeColor.ps1")

function Read-ThemeAnswers {
    param(
        [WslInstanceManager]$Manager,

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
        Write-Host "        Run it on its own:  .\wsl.ps1 theme" -ForegroundColor (Get-MessageColour hint)
        return $null
    }

    # The word the menu shows stays short; the file behind it carries the
    # theme_ prefix, like the command one can type by hand.
    $Choices = @(
        @{ Name = "icon";  File = "theme_icon";  About = "the tile in the tab" },
        @{ Name = "font";  File = "theme_font";  About = "what the whole terminal is written in" },
        @{ Name = "color"; File = "theme_color"; About = "the background, the text, and sixteen colours" }
    )

    # 1. The instance, then the menu - and Escape walks back up the way it
    # came: from the theme menu to the list of instances, so another one can
    # be picked, and from the list to the prompt.
    $Visited = $false
    $Runs = @()

    while ($true) {
        # The menu this one was reached from goes first: the instance list
        # gets a screen of its own.
        Clear-MenuScreen

        $Distro = Select-Distro -Manager $Manager -AllowCancel
        if (-not $Distro) { break }
        $DistroName = $Distro.Name

        Clear-MenuScreen

        # The menu comes back until Escape says the visit to THIS one is
        # over: the level below clears the screen, and this one is drawn on a
        # clean one.
        $Default = 0
        while ($true) {
            Write-Host ""
            $Chosen = Select-FromList -Title "Theme of '$DistroName'" -Items $Choices -Label {
                param($Choice)
                "{0,-6} {1}" -f $Choice.Name, $Choice.About
            } -DefaultIndex $Default

            if (-not $Chosen) { break }

            # The same place next time: two changes are one visit.
            $Default = [array]::IndexOf($Choices, $Chosen)

            # The chosen command's own questions, asked with the instance in
            # hand: what comes back is its whole decision - or nothing, when
            # it was left behind, and the visit goes on either way.
            $Visited = $true
            $ChildForm = $null
            if ($Chosen.File -eq "theme_icon") {
                $ChildForm = Read-ThemeIconAnswers -Manager $Manager -DistroName $DistroName -Options @()
            } elseif ($Chosen.File -eq "theme_font") {
                $ChildForm = Read-ThemeFontAnswers -Manager $Manager -DistroName $DistroName -Options @()
            } else {
                $ChildForm = Read-ThemeColorAnswers -Manager $Manager -DistroName $DistroName -Options @()
            }
            if ($null -ne $ChildForm) {
                $Runs += [PSCustomObject]@{ File = $Chosen.File; Form = $ChildForm }
            }
        }
    }

    # Coming out: the menu goes with the visit. Ending on the menu you have
    # just finished with reads like the command never returned.
    Clear-MenuScreen

    # The menu was never opened: nothing was modified, and it is said once.
    if (-not $Visited) { Stop-Cancelled }

    return [PSCustomObject]@{ Runs = @($Runs) }
}
