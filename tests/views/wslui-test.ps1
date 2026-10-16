# The way in: wsl-fleet.ps1, the one door at the root. Its menu offers the window
# and the console, a word routes to the console, and both entries are checked
# for before they are called - a missing one is said, not a crash.
#
# The menu mechanics themselves - the arrows, the numbered fallback, the
# window arithmetic - are driven for real by menu-test.ps1, which hands the
# classes a scripted console. Here it is the entry's own wiring that is read:
# what it offers, what it calls, and the code it hands back.
#
# It reads, it never runs anything: no instance, no console, no Docker.
#
# Usage:  pwsh -NoProfile -File tests\views\wslui-test.ps1

using module ..\support\common.psm1

$ErrorActionPreference = "Stop"

$global:Failures = 0
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$entry = Get-Content (Join-Path $Root "wsl-fleet.ps1") -Raw

# The menu: its title, its two rows - the words, and the descriptions the
# pages repeat.
Check "the way-in menu is titled Wsl Fleet" ($entry -match 'Add\("gui",\s*"WSL Fleet GUI",\s*\{\s*\}\)' -or $entry -match 'MenuCli\]::new\("Wsl Fleet"\)') $true
Check "the window is offered first, by its word" ($entry -match 'Add\("gui",\s*"WSL Fleet GUI"') $true
Check "the console after it" ($entry -match 'Add\("cli",\s*"WSL Fleet CLI"') $true

# The routing: the words go to the two entries, both checked for first, and
# the console takes the command and the name.
Check "the window's word calls Start-Gui.ps1" ($entry -match 'Join-Path \$Windows "Start-Gui\.ps1"') $true
Check "the console's word calls Start-Cli.ps1" ($entry -match 'Join-Path \$Windows "Start-Cli\.ps1"') $true
Check "a command word travels with its name" ($entry -match '& \$Cli \$Command \$Name') $true
Check "a bare cli opens the console's menu" ($entry -match 'if \(\$Word -eq "cli"\) \{\s*& \$Cli\s*\}') $true
Check "both entries are checked before they are called" ($entry -match 'function Test-Entry' -and ([regex]::Matches($entry, 'Test-Entry \$Gui').Count -ge 1) -and ([regex]::Matches($entry, 'Test-Entry \$Cli').Count -ge 1)) $true
Check "a missing entry is said, not a crash" ($entry -match 'is missing - the src\\windows\\ folder is incomplete') $true
Check "the entry's code is handed back" ([regex]::Matches($entry, 'exit \$LASTEXITCODE').Count -ge 2) $true

# And the files behind the two words are on disk - the same check the entry
# makes at its first line.
Check "Start-Gui.ps1 is there" (Test-Path (Join-Path $Root "src\windows\Start-Gui.ps1")) $true
Check "Start-Cli.ps1 is there" (Test-Path (Join-Path $Root "src\windows\Start-Cli.ps1")) $true

# The other suites: every one of them is spelled in the workflow, and on
# disk - a renamed file would quietly stop running.
$workflow = Get-Content (Join-Path $Root ".github\workflows\ci.yml") -Raw
$suites = [regex]::Matches($workflow, 'tests/([a-z/-]+-test\.(?:ps1|sh))') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
Check "the workflow names suites at all" ($suites.Count -gt 0) $true
foreach ($suite in $suites) {
    Check "the workflow's $suite is on disk" (Test-Path (Join-Path $Root "tests\$suite")) $true
}

Write-Output ""
Write-Output ("failures: " + $global:Failures)
exit $global:Failures
