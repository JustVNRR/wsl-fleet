# The classes this file names, pulled in by the file itself: a type resolves
# for its own reader, whoever launched the command.
using module ..\WslModel\WslModel.psd1
[CmdletBinding()]
param (
    # Injected by wsl.ps1 - the engine every command acts through, made once
    # in the entry. A command is never run by hand any more: the entry loads
    # the module and hands this over, and the `using` above names the type, so
    # it binds from the first line.
    [WslInstanceManager]$Manager,

    # The answers, whole - the console's conversation (src\windows\cli\
    # Controllers\ThemeFont.ps1) renders them: the instance and the fonts
    # picked, in order. This file never asks.
    [object]$Form
)

# What an instance is written in: the font of its Terminal profile - the whole
# terminal, prompt and icons included. Reached through `.\wsl.ps1 theme`.
#
# No console can show a font in itself - a terminal writes every row in the
# font IT is set to - so the preview is the choice itself: the profile changes,
# and the next tab is written in it. Reached on its own, the reload of
# Terminal is the entry's closing move, once the prompt is back.

$ErrorActionPreference = "Stop"

$Distro = $Form.Instance

# The picks, in order, through the instance's own gesture: the profile is ours
# to write - the icon and the colours stay, the font is the one just chosen.
# A machine without the profile throws, and its sentence says it.
foreach ($FontName in @($Form.Fonts)) {
    try {
        $null = $Manager.SetFont($Distro, $FontName)
    } catch {
        Write-Host ""
        Write-Host "[ABORT] $($_.Exception.Message)" -ForegroundColor (Get-MessageColour error)
        Write-Host "        The fonts applied before it stay; this one is not." -ForegroundColor (Get-MessageColour muted)
        exit 1
    }

    if (-not (Test-FontInstalled $FontName)) {
        Write-Host "  Not installed on Windows: '$FontName' - the profile points at it anyway." -ForegroundColor (Get-MessageColour warning)
    }
}
