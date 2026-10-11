# The classes this file names, pulled in by the file itself: a type resolves
# for its own reader, whoever launched the command.
using module ..\WslModel\WslModel.psd1
[CmdletBinding()]
param (
    # Injected by wsl.ps1 - the engine every command acts through, made once
    # in the entry. A command is never run by hand any more: the entry loads
    # the module and hands this over, and the `using` above names the type, so
    # it binds from the first line.
    [WslInstanceManager]$Manager
)

# What an instance wears: its icon, its font and its colours - the three things
# Windows Terminal takes from the profile this repository writes.
#
# The instance comes first, once, then the commands - and each comes back here
# when done, so changing the icon and then the font is one visit.

$ErrorActionPreference = "Stop"

# The word the menu shows stays short; the file behind it carries the theme_
# prefix, like the command one can type by hand.
$Choices = @(
    @{ Name = "icon";  File = "theme_icon";  About = "the tile in the tab" },
    @{ Name = "font";  File = "theme_font";  About = "what the whole terminal is written in" },
    @{ Name = "color"; File = "theme_color"; About = "the background, the text, and sixteen colours" }
)

foreach ($Choice in $Choices) {
    $Script = Join-Path $PSScriptRoot "$($Choice.File).ps1"
    if (-not (Test-Path $Script)) {
        Write-Host ""
        Write-Host "[ABORT] src\windows\WslCommands\$($Choice.File).ps1 is missing - the src\windows\ folder is incomplete." -ForegroundColor (Get-MessageColour error)
        exit 1
    }
}

# 1. Which instance, and then which of the three. Escape walks back up the way
# it came: from the theme menu to the list of instances, so another one can be
# picked, and from the list to the prompt.
$Visited = $false

while ($true) {
    # The menu this one was reached from goes first: the instance list gets a
    # screen of its own.
    Clear-MenuScreen

    $Distro = Select-Distro -Manager $Manager -AllowCancel
    if (-not $Distro) { break }
    $DistroName = $Distro.Name

    Clear-MenuScreen

    # The menu comes back until Escape says the visit to THIS one is over: the
    # level below clears the screen, and this one is drawn on a clean one.
    $Default = 0
    while ($true) {
        Write-Host ""
        $Chosen = Select-FromList -Title "Theme of '$DistroName'" -Items $Choices -Label {
            param($Choice)
            "{0,-6} {1}" -f $Choice.Name, $Choice.About
        } -DefaultIndex $Default

        if (-not $Chosen) { break }

        $Default = [array]::IndexOf($Choices, $Chosen)

        # The command named takes the screen and clears it itself, the way it came in.
        # theme_font and theme_icon have followed the family already: their
        # questions live in the console's conversations and the commands are
        # agnostic - this menu plays the entry's two roles for them until its
        # own lot. theme_color still asks for itself, and is handed the
        # instance as before.
        if ($Chosen.File -eq "theme_font") {
            . (Join-Path $PSScriptRoot "..\cli\Controllers\ThemeFont.ps1")
            $FontAnswers = Read-ThemeFontAnswers -Manager $Manager -DistroName $DistroName -Options @()
            if ($null -ne $FontAnswers) {
                & (Join-Path $PSScriptRoot "theme_font.ps1") -Manager $Manager -Form $FontAnswers
            }
        } elseif ($Chosen.File -eq "theme_icon") {
            . (Join-Path $PSScriptRoot "..\cli\Controllers\ThemeIcon.ps1")
            $IconAnswers = Read-ThemeIconAnswers -Manager $Manager -DistroName $DistroName -Options @()
            if ($null -ne $IconAnswers) {
                & (Join-Path $PSScriptRoot "theme_icon.ps1") -Manager $Manager -Form $IconAnswers
            }
        } else {
            & (Join-Path $PSScriptRoot "$($Chosen.File).ps1") -DistroName $DistroName -Manager $Manager
        }
        $Visited = $true
    }
}

# Coming out: the menu goes with the visit. Ending on the menu you have just
# finished with reads like the command never returned.
Clear-MenuScreen

if (-not $Visited) {
    Write-Host "[ABORT] Operation cancelled by user. Nothing was modified." -ForegroundColor (Get-MessageColour success)
    exit 0
}

# The visit is over, and this is the moment Terminal can be asked to look again:
# a reload cannot land on a pane that is running a menu, so the change shows
# when you leave, not while you are still in there.
Update-TerminalSettings

# And nothing is said: the change is in the tab, and a line explaining that
# would be one line too many.
exit 0