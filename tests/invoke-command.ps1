# Runs one command of scripts\WslCommands\ the way wsl.ps1 does: the module is
# imported here, first, for the case - the commands carry no load of their own
# any more, they run through the entry and use what it imported. The manager
# travels in as a parameter, typed and bound from the command's first line -
# and for the commands whose questions live in the console's conversation
# (archive, restore, duplicate, unregister, shrink, migrate, stop), the
# controller is mounted and asked here, and the form it renders travels in
# too: the entry's two roles, played the same way.
#
# The suites drive their commands through this file. The answers travel on
# standard input, as they always did. $LASTEXITCODE is zeroed before the
# command: a run that simply ends returns zero - what -File gave - and a
# command that raises its own exit has it forwarded.
#
# Usage:  $Answers | & $Engine -NoProfile -File tests\invoke-command.ps1 -Script <command.ps1>
using module ..\src\windows\WslModel\WslModel.psd1

[CmdletBinding()]
param (
    [Parameter(Mandatory)][string]$Script
)

$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "..\src\windows\WslStack\WslStack.psd1") -Force

$LASTEXITCODE = 0
# The manager, made the way the entry makes it - Root answers a choice (and
# may say it took up home elsewhere), not the bare path any more.
$Manager = New-InstanceManager

# The commands whose questions live in the console's conversation take their
# answers the way they do at the entry: the controller is mounted, asked, and
# the form it renders travels to the command - the two roles wsl.ps1 plays.
# A conversation that refuses (unknown words, nothing to pick) ends the run
# on one, as the entry does.
$Key = [IO.Path]::GetFileNameWithoutExtension($Script)
$Form = $null
$Asks = $true
if ($Key -eq "archive") {
    . (Join-Path $PSScriptRoot "..\src\windows\cli\Controllers\Archive.ps1")
    $Form = Read-ArchiveAnswers -Manager $Manager -Options @()
} elseif ($Key -eq "restore") {
    . (Join-Path $PSScriptRoot "..\src\windows\cli\Controllers\Restore.ps1")
    $Form = Read-RestoreAnswers -Manager $Manager -Options @()
} elseif ($Key -eq "duplicate") {
    . (Join-Path $PSScriptRoot "..\src\windows\cli\Controllers\Duplicate.ps1")
    $Form = Read-DuplicateAnswers -Manager $Manager -Options @()
} elseif ($Key -eq "unregister") {
    . (Join-Path $PSScriptRoot "..\src\windows\cli\Controllers\Unregister.ps1")
    $Form = Read-UnregisterAnswers -Manager $Manager -Options @()
} elseif ($Key -eq "shrink") {
    . (Join-Path $PSScriptRoot "..\src\windows\cli\Controllers\Shrink.ps1")
    $Form = Read-ShrinkAnswers -Manager $Manager -Options @()
} elseif ($Key -eq "migrate") {
    . (Join-Path $PSScriptRoot "..\src\windows\cli\Controllers\Migrate.ps1")
    $Form = Read-MigrateAnswers -Manager $Manager -Options @()
} elseif ($Key -eq "stop") {
    . (Join-Path $PSScriptRoot "..\src\windows\cli\Controllers\Stop.ps1")
    $Form = Read-StopAnswers -Manager $Manager -Options @()
} else {
    $Asks = $false
}
if ($Asks -and $null -eq $Form) { exit 1 }

if ($Asks) { & $Script -Form $Form -Manager $Manager }
else { & $Script -Manager $Manager }
exit $LASTEXITCODE
