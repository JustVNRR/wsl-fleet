# The name a Windows account proposes, cleaned for the user name question: no
# build, no console, no instance - $env:USERNAME is set case by case.
#
# The rule it checks: lowercase, accents unfolded, separators turned into
# single dashes, the dashes and underscores framing the name trimmed - and
# nothing proposed when what remains cannot be a user name, because a name
# the build made up would be worse than no proposal.
#
# The rule is written in the two homes that propose it - the console's build
# presenter and the window's BuildViewModel: the checks drive the window's,
# and the last one reads both files and asks that the two copies stay the
# same text, since a drift there would propose two different names to two
# faces.
#
# Usage:  pwsh -NoProfile -File tests\user-name-test.ps1
using module ..\src\windows\ViewModels\BuildViewModel.psm1

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

# The proposal of the window's ViewModel: its constructor reads the Windows
# account name and cleans it, so one build made per case answers the rule.
function ProposalOf {
    param([string]$WindowsName)
    $env:USERNAME = $WindowsName
    return ([BuildViewModel]::new($null)).User
}

Write-Output "--- separators become single dashes ---"
Check "Jean.Dupont" (ProposalOf "Jean.Dupont") "jean-dupont"
Check "Jean Dupont, the same" (ProposalOf "Jean Dupont") "jean-dupont"
Check "a run of them collapses" (ProposalOf "Jean  .  Dupont") "jean-dupont"

Write-Output ""
Write-Output "--- the rest is lowered, accents unfolded ---"
Check "ÉLODIE" (ProposalOf "ÉLODIE") "elodie"
Check "René" (ProposalOf "René") "rene"
Check "Jean_PC keeps its underscore" (ProposalOf "Jean_PC") "jean_pc"
Check "vieux-PC keeps its dash" (ProposalOf "vieux-PC") "vieux-pc"

Write-Output ""
Write-Output "--- the framing is trimmed ---"
Check "_jean" (ProposalOf "_jean") "jean"
Check "-jean" (ProposalOf "-jean") "jean"
Check "jean." (ProposalOf "jean.") "jean"

Write-Output ""
Write-Output "--- nothing when no user name can be made ---"
Check "a name starting with a digit" (ProposalOf "2fast") ""
Check "only separators" (ProposalOf "...") ""
Check "an empty name" (ProposalOf "") ""
Check "an underscore alone" (ProposalOf "_") ""

Write-Output ""
Write-Output "--- the two homes of the rule say the same thing ---"
# The cleaning block, as written in each file - trimmed line by line so the
# indentation differs freely, the words not.
function CleaningBlock {
    param([string]$Path)
    $Text = [IO.File]::ReadAllText((Join-Path $PSScriptRoot $Path))
    $Match = [regex]::Match($Text, '(?s)\$proposal = "\$env:USERNAME"\.ToLower\(\).*?\$proposal = ""')
    if (-not $Match.Success) { return "" }
    return ((@($Match.Value -split "`n") | ForEach-Object { "$_".Trim() }) -join "|")
}
$InVm = CleaningBlock "..\src\windows\ViewModels\BuildViewModel.psm1"
$InConsole = CleaningBlock "..\src\windows\Presenters\Instance\BuildPresenter.psm1"
Check "the cleaning is found in both homes" (($InVm.Length -gt 0) -and ($InConsole.Length -gt 0)) $true
Check "and the two copies are the same text" ($InVm -eq $InConsole) $true

Write-Output ""
Write-Output ("failures: " + $Failures)
exit $Failures
