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
    # Controllers\ThemeIcon.ps1) renders them: the instance, and what the
    # visit decided - an image of your own, or the settled recipe. This file
    # never asks.
    [object]$Form
)

# The icon is a file, not a setting: terminal-icon.png in the instance's own
# folder, the one the Terminal profile points at. Nothing has to be stopped
# for it: an icon belongs to a tab as it is opened. Reached through
# `.\wsl.ps1 theme`.

$ErrorActionPreference = "Stop"

$Distro = $Form.Instance

# An image of your own takes the picture's place; the recipe behind it stays.
# Otherwise the drawing, whole - settled already, and worn as it is. A failure
# leaves the icon that was there.
if ($Form.Image) {
    try {
        $null = $Manager.SetIconImage($Distro, $Form.Image)
    } catch {
        Write-Host ""
        Write-Host "[ABORT] The image could not be copied into place: $($_.Exception.Message)" -ForegroundColor (Get-MessageColour error)
        Write-Host "        The icon that was there is still there." -ForegroundColor (Get-MessageColour muted)
        exit 1
    }
} else {
    try {
        $null = $Manager.SetIcon($Distro, $Form.Recipe)
    } catch {
        Write-Host ""
        Write-Host "[ABORT] The icon could not be drawn: $($_.Exception.Message)" -ForegroundColor (Get-MessageColour error)
        Write-Host "        The icon that was there is still there." -ForegroundColor (Get-MessageColour muted)
        exit 1
    }
}
