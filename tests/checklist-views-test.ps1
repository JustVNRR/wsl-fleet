# Le choix entier des vues, conduit par le VRAI menu — le repli numéroté sur
# l'entrée standard — et ce qu'il REND : des lignes à plat pour un choix, une
# liste vide pour rien coché, rien du tout pour l'Échap.
#
# C'est la forme qui a été cassée sans un bruit : la virgule d'AskChecklist,
# sous un retour typé [object[]], imbriquait le tableau — le choix entier
# arrivait comme une seule ligne, et le service lisait un nom qui n'existe
# pas (vécu : un pack déjà porté proposé au retrait pendant qu'il était
# réinstallé). Les bancs à fausse vue ne voyaient rien : c'est la vraie vue
# qui parle ici.
#
# Usage:  pwsh -NoProfile -File tests\checklist-views-test.ps1 < tests\checklist-views.answers
using module ..\src\windows\Views\cli\Instance\ManagePacks.psm1
using module ..\src\windows\Views\cli\Instance\Build.psm1

$ErrorActionPreference = "Stop"

$Failures = 0
function Check {
    param([string]$Name, $Got, $Expected)
    if ("$Got" -eq "$Expected") {
        Write-Output "OK   $Name"
    } else {
        Write-Output "FAIL $Name : expected '$Expected', got '$Got'"
        $script:Failures++
    }
}

$view = [CliManagePacksView]::new()
$rows = @("a", "b", "c")

# 1. La case pré-cochée et une cochée : deux lignes À PLAT, dans l'ordre du
# menu.
$picked = $view.AskPacks("bench", $rows, @(2))
Check "pre-checked + picked -> the two rows, flat" ("$(@($picked).Count)/$(@($picked) -join ',')") "2/a,c"
Check "  ... and no nesting in sight" (@($picked | Where-Object { $_ -is [object[]] }).Count) 0

# 2. Rien coché : une liste VIDE, pas rien du tout.
$picked = $view.AskPacks("bench", $rows, @())
Check "nothing checked -> an empty list, not a cancel" "$($null -eq $picked)/$(@($picked).Count)" "False/0"

# 3. Échap : rien du tout.
$picked = $view.AskPacks("bench", $rows, @(0))
Check "the escape -> nothing at all" ($null -eq $picked) $true

# 4. La vue du build : la même forme, ses lignes à elle.
$buildView = [CliBuildView]::new()
$packRows = @(
    [PSCustomObject]@{ Name = "one"; Family = "debian"; Description = "d1"; Shell = $false }
    [PSCustomObject]@{ Name = "two"; Family = "debian"; Description = "d2"; Shell = $true }
)
$picked = $buildView.AskPacks("bench", $packRows, @(1), "note")
Check "the build's checklist, same shape" ("$(@($picked).Count)/$(@($picked.Name) -join ',')") "2/one,two"
Check "  ... and no nesting there either" (@($picked | Where-Object { $_ -is [object[]] }).Count) 0

Write-Output ""
Write-Output ("failures: " + $Failures)
exit $Failures
