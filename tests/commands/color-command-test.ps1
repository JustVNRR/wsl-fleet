# Drives the colour half of `.\wsl-fleet.ps1 theme` the way a script would: the
# numbered prompt, answers on standard input, no console anywhere.
#
# The instance it works on exists for the length of the test: a registry key
# of its own, a folder carrying the marker, the WSL fragment a profile is
# looked up by, and the profile this repository writes, naming a scheme of the
# test's own - so one name in the list is certainly there, whatever the
# machine has. Everything lives under a working folder of the suite's.
#
# The children are the entry itself, wsl-fleet.ps1, run with the theme word.
#
# What is checked: the schemes this machine can wear are listed, the one in
# use is marked, and picking one writes it into the profile this repository
# owns and into the instance's own file - the icon's recipe kept with it. The
# list is read from a first run that cancels, so the number given to the
# second was really in it.
#
# It needs no instance, no console and no Docker Desktop.
#
# Usage:  pwsh -NoProfile -File tests\commands\color-command-test.ps1
using module ..\..\src\windows\Services\ServiceFactory.psm1
using module ..\support\common.psm1

$ErrorActionPreference = "Stop"

$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("color-command-test-" + [Guid]::NewGuid().ToString("N"))
$FakeName = "color-command-test"
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
$Recipe = Join-Path $FakeFolder "instance.json"

$WslFragment = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\Microsoft.WSL\{2f9f0a4e-58b1-4a3c-9d2e-0c1b2a3d4e7f}.json"
$OurFragment = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\wsl-fleet\$FakeName.json"
$OurFragmentExisted = Test-Path $OurFragment

# Put in the profile before the test starts: whatever else the machine offers,
# this one is in the list.
$Planted = "Test Scheme Alpha"

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

# The rows of the numbered list, from the title of the colour menu down: the
# instance list above it is drawn the same way, and its rows are not schemes.
function Get-ListedSchemes {
    param([object[]]$Lines)

    $Rows = @()
    $Inside = $false
    foreach ($Line in $Lines) {
        if ("$Line" -like "Colours of '*'") { $Inside = $true; continue }
        if (-not $Inside) { continue }
        if ("$Line" -match '^\s*(\d+)\.\s+(\S.*?)\s*$') {
            if ($Matches[1] -eq "0") { return $Rows }
            $Rows += ($Matches[2] -replace '\s{2,}.*$', '')
        }
    }
    return $Rows
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
            "guid": "{2f9f0a4e-58b1-4a3c-9d2e-0c1b2a3d4e7f}"
        }
    ]
}
"@

    New-Item -ItemType Directory -Path (Split-Path -Parent $OurFragment) -Force | Out-Null
    Set-Content -Path $OurFragment -Encoding Utf8 -Value @"
{
    "profiles": [
        {
            "updates": "{2f9f0a4e-58b1-4a3c-9d2e-0c1b2a3d4e7f}",
            "font": { "face": "Consolas" },
            "colorScheme": "$Planted"
        }
    ]
}
"@

    # The look a drawing left behind: a colour change must keep it too - one
    # change keeps the others, and the icon question starts from these letters.
    @{
        DefaultUser = "qtest"
        Theme       = @{
            Font          = "MesloLGS NF"
            ColorScheme   = $Planted
            IconFrom      = (Join-Path $FakeFolder "terminal-icon.png")
            IconText      = "CT"
            IconTop       = "#111111"
            IconBottom    = "#222222"
            IconTextColor = "#FFFFFF"
        }
    } | ConvertTo-Json -Depth 4 | Set-Content -Path $Recipe -Encoding Utf8

    # Which number our instance is in the list the command draws - worked out
    # with the same code the entry builds.
    $root = [ServiceFactory]::ResolveRoot($Assets, $distroTree)
    $service = [ServiceFactory]::CreateInstanceService($root, $Assets, $distroTree)
    $rows = @($service.GetAll() | Where-Object { -not $_.IsArchive })
    $Pick = [array]::IndexOf(@($rows.Name), $FakeName) + 1
    Check "the test's instance is in the list" ($Pick -ge 1) $true

    # 1. The list, read off a run that cancels. The answers: the instance, the
    # colour row, leave the colour list, leave the theme menu.
    $Out = Invoke-Theme @("$Pick", "3", "0", "0")
    $Schemes = @(Get-ListedSchemes $Out)
    Check "the schemes are listed" ($Schemes.Count -ge 1) $true

    # Every row has the same width, the mark's column included: the names are
    # padded inside the colours, or the list is bars of different lengths.
    $Widths = @()
    $Inside = $false
    foreach ($Line in $Out) {
        if ("$Line" -like "Colours of '*'") { $Inside = $true; continue }
        if (-not $Inside) { continue }
        if ("$Line" -match '^\s*0\.') { break }
        if ("$Line" -match '^\s*\d+\.\s+(.*)$') { $Widths += $Matches[1].Length }
    }
    Check "every row is the same width" (@($Widths | Sort-Object -Unique).Count) 1
    Check "the one the instance wears is in it" ($Schemes -contains $Planted) $true
    Check "and it is marked as the one in use" (@($Out | Where-Object { "$_" -like "*(current)*" }).Count -gt 0) $true
    Check "cancelling applied nothing" ((Get-Content $OurFragment -Raw | ConvertFrom-Json).profiles[0].colorScheme) $Planted

    # 2. Picking one: the number it had in that list, given to a second run -
    # the list is the machine's, so the scheme picked is whichever is number
    # one.
    $null = Invoke-Theme @("$Pick", "3", "1", "0", "0")

    $Written = Get-Content $OurFragment -Raw | ConvertFrom-Json
    Check "the scheme is written into our profile" $Written.profiles[0].colorScheme $Schemes[0]
    Check "  ... under the guid Terminal knows" $Written.profiles[0].updates "{2f9f0a4e-58b1-4a3c-9d2e-0c1b2a3d4e7f}"
    Check "  ... and the font is kept beside it" ($Written.profiles[0].font.face -ne $null) $true

    $Saved = Get-Content $Recipe -Raw | ConvertFrom-Json
    Check "and into the instance's own file" $Saved.Theme.ColorScheme $Schemes[0]
    Check "and the icon's recipe survives the change" $Saved.Theme.IconText "CT"
    Check "  ... colours and all" "$($Saved.Theme.IconTop) $($Saved.Theme.IconBottom) $($Saved.Theme.IconTextColor)" "#111111 #222222 #FFFFFF"
} finally {
    Remove-Item $Key -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $WslFragment -Force -ErrorAction SilentlyContinue
    if (-not $OurFragmentExisted) { Remove-Item $OurFragment -Force -ErrorAction SilentlyContinue }
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
