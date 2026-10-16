# The views' whole choice, driven by the REAL menu - the numbered fallback on
# standard input - and what it RETURNS: flat lines for a pick, an empty list
# for nothing checked, nothing at all for Escape.
#
# This is the shape that broke without a sound: AskChecklist's comma, under a
# typed [object[]] return, nested the array - the whole choice arrived as a
# single line, and the service read a name that does not exist (lived: a pack
# already carried offered for removal while it was reinstalled). The fake-view
# benches saw nothing: the real view speaks here.
#
# Usage:  pwsh -NoProfile -File tests\views\checklist-views-test.ps1 < tests\views\checklist-views.answers
using module ..\..\src\windows\Views\cli\Instance\ManagePacks.psm1
using module ..\..\src\windows\Views\cli\Instance\Build.psm1
using module ..\support\common.psm1

$ErrorActionPreference = "Stop"

$global:Failures = 0

$view = [CliManagePacksView]::new()
$rows = @("a", "b", "c")

# 1. The pre-checked box and one more picked: two FLAT lines, in the menu's
# order.
$picked = $view.AskPacks("bench", $rows, @(2))
Check "pre-checked + picked -> the two rows, flat" ("$(@($picked).Count)/$(@($picked) -join ',')") "2/a,c"
Check "  ... and no nesting in sight" (@($picked | Where-Object { $_ -is [object[]] }).Count) 0

# 2. Nothing checked: an EMPTY list, not nothing at all.
$picked = $view.AskPacks("bench", $rows, @())
Check "nothing checked -> an empty list, not a cancel" "$($null -eq $picked)/$(@($picked).Count)" "False/0"

# 3. Escape: nothing at all.
$picked = $view.AskPacks("bench", $rows, @(0))
Check "the escape -> nothing at all" ($null -eq $picked) $true

# 4. The build's view: the same shape, its own lines.
$buildView = [CliBuildView]::new()
$packRows = @(
    [PSCustomObject]@{ Name = "one"; Family = "debian"; Description = "d1"; Shell = $false }
    [PSCustomObject]@{ Name = "two"; Family = "debian"; Description = "d2"; Shell = $true }
)
$picked = $buildView.AskPacks("bench", $packRows, @(1), "note")
Check "the build's checklist, same shape" ("$(@($picked).Count)/$(@($picked.Name) -join ',')") "2/one,two"
Check "  ... and no nesting there either" (@($picked | Where-Object { $_ -is [object[]] }).Count) 0

Write-Output ""
Write-Output ("failures: " + $global:Failures)
exit $global:Failures
