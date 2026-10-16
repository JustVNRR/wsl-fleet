# Drives the icon half of `.\wsl-fleet.ps1 theme` the way a script would: the
# numbered prompt, answers on standard input, no console anywhere.
#
# The instance it works on exists for the length of the test: a registry key
# of this test's own, a folder carrying the marker, and the WSL fragment
# Terminal reads a profile from. The answers are numbers, worked out from the
# same list the question shows, so the number points at ours whatever else is
# installed; everything lives under a working folder of the suite's, and is
# taken back out at the end.
#
# The children are the entry itself, wsl-fleet.ps1, run with the theme word.
#
# What is checked is what the icon question is for: one change keeps the
# others, Enter takes the letters offered, an image of your own leaves the
# recipe in place, and the automatic one starts over from the name.
#
# It needs no instance, no console and no Docker Desktop.
#
# Usage:  pwsh -NoProfile -File tests\commands\icon-command-test.ps1
using module ..\..\src\windows\Services\ServiceFactory.psm1
using module ..\support\common.psm1

$ErrorActionPreference = "Stop"

$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("icon-command-test-" + [Guid]::NewGuid().ToString("N"))
$FakeName = "icon-command-test"
$Key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss\{2f9f0a4e-58b1-4a3c-9d2e-0c1b2a3d4e5f}"

# The world of the suite: the redirected profile, and the root file pointing
# under it.
$env:USERPROFILE = $Tmp
$env:LOCALAPPDATA = Join-Path $Tmp "LocalAppData"
$env:APPDATA = Join-Path $Tmp "AppData"
New-Item -ItemType Directory -Path (Join-Path $env:LOCALAPPDATA "wsl-fleet") -Force | Out-Null
New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
$Root = Join-Path $Tmp "WSL"
Set-Content -Path (Join-Path $env:LOCALAPPDATA "wsl-fleet\root.txt") -Value $Root -Encoding ascii
$FakeFolder = Join-Path $Root $FakeName
$IconPath = Join-Path $FakeFolder "terminal-icon.png"
# One file per instance, in its folder: the look's own record.
$Recipe = Join-Path $FakeFolder "instance.json"

$WslFragment = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\Microsoft.WSL\{2f9f0a4e-58b1-4a3c-9d2e-0c1b2a3d4e5f}.json"
$Settings = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

# The entry, spelled the way a user's script spells it.
$Entry = Join-Path $PSScriptRoot "..\..\wsl-fleet.ps1"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Assets = Join-Path $RepoRoot "assets"
$distroTree = Join-Path $RepoRoot "src\distro"
if (-not (Test-Path $distroTree)) { $distroTree = "" }

# Child processes follow the engine this suite runs under, so a pass under 7
# tests the scripts under 7.
$Engine = if ($PSVersionTable.PSEdition -eq "Core") { "pwsh" } else { "powershell" }

$global:Failures = 0

function Invoke-Theme {
    param([string[]]$Answers)

    $Preference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $Lines = $Answers | & $Engine -NoProfile -File $Entry theme 2>&1
    } finally {
        $ErrorActionPreference = $Preference
    }
    return $Lines
}

function Get-Recipe {
    if (-not (Test-Path $Recipe)) { return $null }
    return (Get-Content $Recipe -Raw | ConvertFrom-Json)
}

New-Item -ItemType Directory -Path $FakeFolder -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $FakeFolder ".wsl-fleet") -Force | Out-Null

try {
    Remove-Item $Key -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -Path $Key -Force | Out-Null
    Set-ItemProperty -Path $Key -Name DistributionName -Value $FakeName
    Set-ItemProperty -Path $Key -Name BasePath -Value $FakeFolder

    New-Item -ItemType Directory -Path (Split-Path -Parent $WslFragment) -Force | Out-Null
    Set-Content -Path $WslFragment -Encoding Utf8 -Value @"
{
    "profiles": [
        {
            "name": "$FakeName",
            "guid": "{2f9f0a4e-58b1-4a3c-9d2e-0c1b2a3d4e5f}"
        }
    ]
}
"@

    # A Terminal the look can be handed to, and watched for the re-read.
    New-Item -ItemType Directory -Path (Split-Path -Parent $Settings) -Force | Out-Null
    Set-Content -Path $Settings -Encoding Utf8 -Value '{ "profiles": { "list": [] } }'

    # The look the instance was built with: a font, a scheme, and no drawing
    # yet - the automatic icon is the one that draws from the name.
    @{
        DefaultUser = "qtest"
        Theme       = @{
            Font          = "MesloLGS NF"
            ColorScheme   = "One Half Dark"
            IconFrom      = ""
        }
    } | ConvertTo-Json -Depth 4 | Set-Content -Path $Recipe -Encoding Utf8

    # Which number our instance is in the list the command draws - worked out
    # with the same code the entry builds.
    $root = [ServiceFactory]::ResolveRoot($Assets, $distroTree)
    $service = [ServiceFactory]::CreateInstanceService($root, $Assets, $distroTree)
    $rows = @($service.GetAll() | Where-Object { -not $_.IsArchive })
    $Pick = [array]::IndexOf(@($rows.Name), $FakeName) + 1
    Check "the test's instance is in the list" ($Pick -ge 1) $true

    # 1. The automatic icon, drawn from the name of the instance. Answers: the
    # instance, then the icon row, "By Default" - which applies at once - and
    # the escapes that end the visit.
    $Out = Invoke-Theme @("$Pick", "1", "1", "0", "0")
    Check "the icon is drawn" (Test-Path $IconPath) $true
    Check "on the instance this test made" (@($Out | Where-Object { "$_".Contains("Icon of '$FakeName'") }).Count -gt 0) $true
    $Saved = Get-Recipe
    Check "the instance's own file is written" (Test-Path $Recipe) $true
    Check "with the look it was built with" $Saved.Theme.Font "MesloLGS NF"
    Check "the letters of the name" $Saved.Theme.IconText "IC"
    $Auto = "$($Saved.Theme.IconTop) $($Saved.Theme.IconBottom) $($Saved.Theme.IconTextColor)"

    # 2. Escape is not a change: the icon is not redrawn.
    $Before = (Get-FileHash $IconPath).Hash
    $null = Invoke-Theme @("$Pick", "1", "0", "0")
    Check "cancelling changes nothing" (Get-FileHash $IconPath).Hash $Before

    # 3. Other letters: they are the ones drawn, the colours stay.
    $null = Invoke-Theme @("$Pick", "1", "2", "xyz", "0", "0")
    $Saved = Get-Recipe
    Check "other letters, typed and capitalised" $Saved.Theme.IconText "XYZ"
    Check "other letters, the colours stay" "$($Saved.Theme.IconTop) $($Saved.Theme.IconBottom) $($Saved.Theme.IconTextColor)" $Auto

    # 4. Other letters, answered with Enter: the question offers the letters the
    # icon has now, and taking that answer changes nothing.
    $Out = Invoke-Theme @("$Pick", "1", "2", "", "0", "0")
    $Saved = Get-Recipe
    Check "text: the letters are offered in the question" (@($Out | Where-Object { "$_".Contains("[XYZ]") }).Count -gt 0) $true
    Check "text: Enter keeps them" $Saved.Theme.IconText "XYZ"

    # 5. Other colours: the pair is the one picked, the letters stay, and each
    # pair is shown with those letters on it.
    $Out = Invoke-Theme @("$Pick", "1", "3", "2", "0", "0")
    $Saved = Get-Recipe
    Check "other colours, the letters stay" $Saved.Theme.IconText "XYZ"
    Check "other colours, the pair picked is on" "$($Saved.Theme.IconTop) $($Saved.Theme.IconBottom)" "#3B82F6 #2563EB"
    Check "and every pair shows the letters" (@($Out | Where-Object { "$_".Contains("XYZ  orange") }).Count -gt 0) $true
    Check "and the pair in use was marked in the list" (@($Out | Where-Object { "$_" -like "*(current)*" }).Count -gt 0) $true

    # 6. An image of your own: copied in place, and the recipe stays - it is what
    # changing your mind starts from, not a description of the picture.
    $Mine = Join-Path $Tmp "mine.png"
    Copy-Item -Path $IconPath -Destination $Mine -Force
    $null = Invoke-Theme @("$Pick", "1", "4", $Mine, "0", "0")
    Check "an image of my own is copied in place" (Get-FileHash $IconPath).Hash (Get-FileHash $Mine).Hash
    $Saved = Get-Recipe
    Check "and the recipe is kept" $Saved.Theme.IconText "XYZ"

    # 7. Changing your mind after an image: the letters come back from the recipe,
    # not from the name.
    $null = Invoke-Theme @("$Pick", "1", "3", "1", "0", "0")
    $Saved = Get-Recipe
    Check "colours again after an image: the letters are the ones drawn" $Saved.Theme.IconText "XYZ"
    Check "and the pair is the one picked" "$($Saved.Theme.IconTop) $($Saved.Theme.IconBottom)" "#CF7040 #B95E30"

    # 8. The automatic one is the one that starts over from the name.
    $null = Invoke-Theme @("$Pick", "1", "1", "0", "0")
    $Saved = Get-Recipe
    Check "the automatic one starts over from the name" $Saved.Theme.IconText "IC"

    # 9. Two changes in one visit: the first applies at once and the hub comes
    # back, the second keeps what the first did - the letters AND the colours.
    $null = Invoke-Theme @("$Pick", "1", "2", "abc", "1", "3", "2", "0")
    $Saved = Get-Recipe
    Check "two changes in one run: the letters are the typed ones" $Saved.Theme.IconText "ABC"
    Check "two changes in one run: and the colours are the picked ones" "$($Saved.Theme.IconTop) $($Saved.Theme.IconBottom)" "#3B82F6 #2563EB"

    # 10. The way in: the instance is asked once, the menu holds the three
    # questions, and it is drawn again while the visit lasts. Answers: the
    # instance, "icon", "By Default" (which changes something), Escape on the
    # icon menu, Escape here. The file Terminal watches is touched on the way.
    $Before = (Get-Item $Settings).LastWriteTime
    $Out = Invoke-Theme @("$Pick", "1", "1", "0", "0")

    Check "theme offers its three questions" (@($Out | Where-Object { "$_".Contains("what the whole terminal is written in") }).Count -gt 0) $true
    Check "hands over to the icon question" (@($Out | Where-Object { "$_".Contains("Icon of '$FakeName'") }).Count -gt 0) $true
    Check "and the menu is drawn again once the question returns" (@($Out | Where-Object { "$_" -eq "Theme of '$FakeName'" }).Count) 2
    Check "and Terminal was asked to look again" ((Get-Item $Settings).LastWriteTime -gt $Before) $true
} finally {
    Remove-Item $Key -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $WslFragment -Force -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
}

Write-Output ""
Write-Output ("failures: " + $global:Failures)

if ($global:Failures -gt 0) {
    Write-Output ""
    Write-Output "--- the last run's own words ---"
    foreach ($Line in @($Out)) { Write-Output "    | $Line" }
}
exit $global:Failures
