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
    # Controllers\ThemeColour.ps1) renders them: the instance and the schemes
    # picked, in order. This file never asks.
    [object]$Form
)

# What a terminal's colours are: the colour scheme of its profile - the
# background, the text, and the sixteen colours a program may ask for by
# number. Reached through `.\wsl.ps1 theme`.

$ErrorActionPreference = "Stop"

$Distro = $Form.Instance

# The picks, in order, through the instance's own gesture: the profile is ours
# to write - the icon and the font stay, the scheme is the one just chosen. A
# machine without the profile throws, and its sentence says it.
foreach ($SchemeName in @($Form.Schemes)) {
    try {
        $null = $Manager.SetColourScheme($Distro, $SchemeName)
    } catch {
        Write-Host ""
        Write-Host "[ABORT] $($_.Exception.Message)" -ForegroundColor (Get-MessageColour error)
        Write-Host "        The schemes applied before it stay; this one is not." -ForegroundColor (Get-MessageColour muted)
        exit 1
    }
}
