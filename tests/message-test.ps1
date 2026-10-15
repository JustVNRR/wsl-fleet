# The colour of a message, on schemes written out here: no terminal window, no
# instance, no console.
#
# The rule it checks: a scheme keeps two versions of each colour, the one read
# on its own background is the one used, and where a scheme offers nothing
# readable - a light scheme whose white is its own background - that kind is
# written in the scheme's own text colour.
#
# The colours below are the real values of schemes Windows Terminal ships,
# except the fourth, written as a list - the other way a scheme may be written.
#
# The scheme is staged where the class reads it - the window's settings file,
# under a redirected LOCALAPPDATA - and the cache the class keeps for the
# length of a command is dropped between the scenes.
#
# Usage:  pwsh -NoProfile -File tests\message-test.ps1
using module ..\src\windows\Views\cli\ThemeCli.psm1
using module ..\src\windows\Views\cli\BaseViewCli.psm1

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

# The window's settings, written where the class looks - the last of the three
# paths it knows, the one this repository's own fragments live beside. Two
# writes for one file: the provider settles a name with forward slashes, .NET
# keeps the path as it is written, and on a Windows host the two are the same
# path.
$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("message-test-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $Tmp -Force | Out-Null
$env:LOCALAPPDATA = $Tmp
$SettingsPath = [ThemeCli]::TerminalSettings[2]
$SettingsPlain = $SettingsPath.Replace([char]92, [char]47)

function Write-Settings([string]$Text) {
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($SettingsPlain)) | Out-Null
    [IO.File]::WriteAllText($SettingsPlain, $Text)
    [IO.File]::WriteAllText($SettingsPath, $Text)
}

function Reset-Theme {
    [ThemeCli]::ThemeRead = $false
    [ThemeCli]::Theme = $null
}

function Stage-Scheme([string]$Name, $Scheme) {
    Write-Settings (@{ profiles = @{ defaults = @{ colorScheme = $Name } }; schemes = @($Scheme) } | ConvertTo-Json -Depth 8)
    $env:WT_PROFILE_ID = "{11111111-2222-3333-4444-555555555555}"
    Reset-Theme
}

$OneHalfDark = @{
    name = "One Half Dark"; background = "#282C34"; foreground = "#DCDFE4"
    black = "#282C34"; red = "#E06C75"; green = "#98C379"; yellow = "#E5C07B"
    blue = "#61AFEF"; purple = "#C678DD"; cyan = "#56B6C2"; white = "#DCDFE4"
    brightBlack = "#5A6374"; brightRed = "#E06C75"; brightGreen = "#98C379"; brightYellow = "#E5C07B"
    brightBlue = "#61AFEF"; brightPurple = "#C678DD"; brightCyan = "#56B6C2"; brightWhite = "#DCDFE4"
}

$OneHalfLight = @{
    name = "One Half Light"; background = "#FAFAFA"; foreground = "#383A42"
    black = "#383A42"; red = "#E45649"; green = "#50A14F"; yellow = "#C18301"
    blue = "#0184BC"; purple = "#A626A4"; cyan = "#0997B3"; white = "#FAFAFA"
    brightBlack = "#4F525D"; brightRed = "#DF6C75"; brightGreen = "#98C379"; brightYellow = "#E4C07A"
    brightBlue = "#61AFEF"; brightPurple = "#C678DD"; brightCyan = "#56B5C1"; brightWhite = "#FFFFFF"
}

# Its quiet grey is its own background, and reading it would put the footnotes
# out of sight - the one case where a kind has to look further than its colour.
$SolarizedDark = @{
    name = "Solarized Dark"; background = "#002B36"; foreground = "#839496"
    black = "#002B36"; red = "#DC322F"; green = "#859900"; yellow = "#B58900"
    blue = "#268BD2"; purple = "#D33682"; cyan = "#2AA198"; white = "#EEE8D5"
    brightBlack = "#073642"; brightRed = "#CB4B16"; brightGreen = "#586E75"; brightYellow = "#657B83"
    brightBlue = "#839496"; brightPurple = "#6C71C4"; brightCyan = "#93A1A1"; brightWhite = "#FDF6E3"
}

try {
    Write-Output "--- nothing to read: the names every console has always had ---"
    # A console window, VS Code, CI: the names this project used before this
    # file existed. A run inside a Windows Terminal window (WT_PROFILE_ID
    # set) must answer like one anywhere else, so the window is taken away.
    Remove-Item Env:\WT_PROFILE_ID -ErrorAction SilentlyContinue
    Reset-Theme
    Check "error   -> Red" ([ThemeCli]::GetColor("error")) "Red"
    Check "warning -> Yellow" ([ThemeCli]::GetColor("warning")) "Yellow"
    Check "success -> Green" ([ThemeCli]::GetColor("success")) "Green"
    Check "info    -> Cyan" ([ThemeCli]::GetColor("info")) "Cyan"
    Check "muted   -> DarkGray" ([ThemeCli]::GetColor("muted")) "DarkGray"
    Check "hint    -> White" ([ThemeCli]::GetColor("hint")) "White"
    Check "danger  -> DarkRed" ([ThemeCli]::GetColor("danger")) "DarkRed"
    Check "and it is a colour a console takes" (([ThemeCli]::GetColor("error")).GetType().Name) "ConsoleColor"

    Write-Output ""
    Write-Output "--- a dark scheme: what this project has always written in ---"
    # The same value for both versions of each colour here - and that is the
    # point: the scheme this project has been read in comes out unchanged.
    Stage-Scheme "One Half Dark" $OneHalfDark
    Check "error   -> Red" ([ThemeCli]::GetColor("error")) "Red"
    Check "warning -> Yellow" ([ThemeCli]::GetColor("warning")) "Yellow"
    Check "success -> Green" ([ThemeCli]::GetColor("success")) "Green"
    Check "info    -> Cyan" ([ThemeCli]::GetColor("info")) "Cyan"
    Check "muted   -> DarkGray (readable on it: 2.31)" ([ThemeCli]::GetColor("muted")) "DarkGray"
    Check "hint    -> White" ([ThemeCli]::GetColor("hint")) "White"

    Write-Output ""
    Write-Output "--- a light scheme: the version that is read on it ---"
    # One Half Light paints its bright half in pastels - white on it is its own
    # background, and hint reads nothing at all, so it falls to the colour the
    # scheme writes its own text in.
    Stage-Scheme "One Half Light" $OneHalfLight
    Check "error   -> DarkRed    (read best against its bright red)" ([ThemeCli]::GetColor("error")) "DarkRed"
    Check "warning -> DarkYellow" ([ThemeCli]::GetColor("warning")) "DarkYellow"
    Check "success -> DarkGreen" ([ThemeCli]::GetColor("success")) "DarkGreen"
    Check "info    -> DarkCyan" ([ThemeCli]::GetColor("info")) "DarkCyan"
    Check "muted   -> DarkGray" ([ThemeCli]::GetColor("muted")) "DarkGray"
    Check "hint    -> Black, the colour it writes its text in" ([ThemeCli]::GetColor("hint")) "Black"
    Check "  ... which is its foreground, #383A42" ([ThemeCli]::GetSchemeColour($OneHalfLight, "Black")) "#383A42"

    Write-Output ""
    Write-Output "--- a quiet colour that cannot be read is not used ---"
    # Its bright black sits on its own background: a footnote written in it would
    # not be seen, so its text colour - one of its sixteen - is used instead.
    Stage-Scheme "Solarized Dark" $SolarizedDark
    Check "muted -> Blue (its text colour), not DarkGray" ([ThemeCli]::GetColor("muted")) "Blue"
    Check "  ... which is its foreground, #839496" ([ThemeCli]::GetSchemeColour($SolarizedDark, "Blue")) "#839496"

    Write-Output ""
    Write-Output "--- a scheme written as a list ---"
    # Sixteen rows in ANSI order, not console order: red is the second row here
    # and the fourth value of [ConsoleColor] - read by console number, every
    # error would come out green.
    $AsList = @{
        name = "Written as a list"; background = "#000000"; foreground = "#FFFFFF"
        palette = @(
            "#101010", "#202020", "#303030", "#404040", "#505050", "#606060", "#707070", "#808080",
            "#909090", "#A0A0A0", "#B0B0B0", "#C0C0C0", "#D0D0D0", "#E0E0E0", "#F0F0F0", "#FFFFFF"
        )
    }
    Check "dark red is the second row" ([ThemeCli]::GetSchemeColour($AsList, "DarkRed")) "#202020"
    Check "bright red is the tenth, not the fourth" ([ThemeCli]::GetSchemeColour($AsList, "Red")) "#A0A0A0"
    Check "and the footnotes' colour is the eighth" ([ThemeCli]::GetSchemeColour($AsList, "Gray")) "#808080"

    Write-Output ""
    Write-Output "--- a kind that is not one of the seven ---"
    $Refused = $false
    try { $null = [ThemeCli]::GetColor("purple") } catch { $Refused = $true }
    Check "an unknown kind is refused, not guessed" $Refused $true

    Write-Output ""
    Write-Output "--- the DANGER banner ---"
    # Two colours read together, so it is drawn rather than asked for: the
    # scheme's red as background, and its text read on that red. The banner is
    # the view's, on the class's pair.
    Stage-Scheme "Solarized Dark" $SolarizedDark
    $Pair = [ThemeCli]::GetBannerColors()
    Check "the box is one of the scheme's two reds" (@("DarkRed", "Red") -contains "$($Pair.Box)") $true
    $View = [BaseViewCli]::new()
    $Lines = @(& { $View.ShowDangerBanner("DANGER: TOTAL DATA LOSS IMMINENT") } 6>&1)
    Check "three lines" $Lines.Count 3
    Check "and the middle one still says what it said" (@($Lines | Where-Object { "$_" -like "*DANGER: TOTAL DATA LOSS IMMINENT*" }).Count) 1
    Check "the first and last are the rules around it" (@($Lines | Where-Object { "$_" -like "*====*" }).Count) 2
} finally {
    Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
    foreach ($Path in @($SettingsPath, $SettingsPlain)) {
        try { [IO.File]::Delete($Path) } catch { }
    }
}

Write-Output ""
Write-Output ("failures: " + $Failures)
exit $Failures
