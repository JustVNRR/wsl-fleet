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
    # Controllers\Theme.ps1) renders them: the visit's runs, in order, each
    # with the instance and the decision. This file never asks.
    [object]$Form
)

# What an instance wears: its icon, its font and its colours - the three
# things Windows Terminal takes from the profile this repository writes.
# Reached on its own, the reload of Terminal is the entry's closing move,
# once the prompt is back.

$ErrorActionPreference = "Stop"

# The visit's runs, in order, each through the command that owns it. A run
# that failed said so already, and the ones after it still go: what the visit
# decided stands whatever hiccup one run met.
foreach ($Run in @($Form.Runs)) {
    $Script = Join-Path $PSScriptRoot "$($Run.File).ps1"
    if (-not (Test-Path $Script)) {
        Write-Host ""
        Write-Host "[ABORT] src\windows\WslCommands\$($Run.File).ps1 is missing - the src\windows\ folder is incomplete." -ForegroundColor (Get-MessageColour error)
        exit 1
    }
    & $Script -Manager $Manager -Form $Run.Form
}

# Whatever a run's own code was, the visit itself ran to the end - and a
# console build that ends bare would leave the last code standing, the
# entry's reload reading it.
exit 0
