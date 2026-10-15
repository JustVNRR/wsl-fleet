# The surface of the CLI: every gesture a word rides on exists, and every
# view a gesture looks up is on disk.
#
#   - every block of Start-Cli.ps1's $gestures table calls a method its
#     presenter carries - a renamed method would only show the day the
#     command runs, in front of the user;
#   - every presenter method that names a view through GetView("X") lands on
#     a file under Views\cli (the Instance folder, the Fleet folder, their
#     shared ones) - a renamed view file is the same kind of silence;
#   - the menu of Start-Cli.ps1 shows each gesture word it routes, and the
#     way-in menu of wsl.ps1 its own two.
#
# It reads, it never runs anything: no instance, no console, no Docker.
#
# Usage:  pwsh -NoProfile -File tests\module-surface-test.ps1

$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Windows = Join-Path $Root "src\windows"
$bad = 0

function Fail([string]$Message) {
    Write-Host "::error::$Message"
    $script:bad = 1
}

$startCli = Get-Content (Join-Path $Windows "Start-Cli.ps1") -Raw

# 1. Every gesture block calls a method its presenter carries.
$seen = @{}
# Les gestes : leur presenter porte la méthode, par convention de nom.
$migrated = [regex]::Matches($startCli, '"([a-z_]+)"\s*=\s*\{\s*param\([^)]*\)\s*\$Presenters\.([A-Za-z]+)\.([A-Za-z]+)\(')
foreach ($m in $migrated) {
    $word = $m.Groups[1].Value
    $presenter = $m.Groups[2].Value
    $method = $m.Groups[3].Value
    $seen[$word] = $true
    $sources = @(
        (Join-Path $Windows "Presenters\Instance\$($presenter)Presenter.psm1"),
        (Join-Path $Windows "Presenters\Fleet\$($presenter)Presenter.psm1")
    )
    $carried = $false
    foreach ($source in $sources) {
        if ((Test-Path $source) -and ((Get-Content $source -Raw) -match "\[ActionResult\]\s+$method\(")) { $carried = $true; break }
    }
    if (-not $carried) { Fail "gesture '$word' calls $($presenter)Presenter.$method - no such method" }
}

# Un bloc d'une autre forme passerait sous le radar : chacun doit se lire ici.
$total = [regex]::Matches($startCli, '"([a-z_]+)"\s*=\s*\{').Count
if ($migrated.Count -ne $total) {
    Fail "$total gesture block(s) in Start-Cli.ps1, only $($migrated.Count) read - a block has another shape"
}
if ($total -eq 0) { Fail "no gesture block found in Start-Cli.ps1 - this check read nothing" }
Write-Host "$total gesture(s) read."

# 2. Every GetView("X") of a presenter lands on a file.
$viewFolders = @(
    (Join-Path $Windows "Views\cli\Instance"),
    (Join-Path (Join-Path $Windows "Views\cli\Instance") "shared"),
    (Join-Path $Windows "Views\cli\Fleet"),
    (Join-Path (Join-Path $Windows "Views\cli\Fleet") "shared"),
    (Join-Path $Windows "Views\cli\shared")
)
$lookers = @{}
foreach ($presenter in @(Get-ChildItem (Join-Path $Windows "Presenters") -Recurse -Filter *.psm1)) {
    $lookers[$presenter.Name] = Get-Content $presenter.FullName -Raw
}
foreach ($name in $lookers.Keys) {
    $views = [regex]::Matches($lookers[$name], 'GetView\("([A-Za-z]+)"\)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
    foreach ($view in $views) {
        $found = $false
        foreach ($folder in $viewFolders) {
            if (Test-Path (Join-Path $folder "$view.psm1")) { $found = $true; break }
        }
        if (-not $found) { Fail "$name looks up the view '$view' - no $view.psm1 under Views\cli" }
    }
}
Write-Host "the presenters' view lookups: read."

# 3. The menu shows each routed word, and the way-in its own two.
$menuWords = [regex]::Matches($startCli, '\$menu = \$menu\.Add\("([a-z_]+)",\s*"([^"]*)"') | ForEach-Object { $_.Groups[1].Value }
foreach ($word in $seen.Keys) {
    if ($word -eq "delete_archive") { continue }      # not in the menu by design: named, not listed
    if ($menuWords -notcontains $word) { Fail "gesture '$word' has no line in Start-Cli's menu" }
}
foreach ($word in $menuWords) {
    if (-not $seen.ContainsKey($word)) { Fail "the menu shows '$word' - no gesture answers it" }
}
$entry = Get-Content (Join-Path $Root "wsl.ps1") -Raw
foreach ($word in @("gui", "cli")) {
    if ($entry -notmatch "Add\(""$word"",") { Fail "the way-in menu lost its '$word' row" }
}
Write-Host "$($menuWords.Count) menu word(s) read."

Write-Host "surface: $bad failure(s)."
exit $bad
