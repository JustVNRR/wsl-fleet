# ==============================================================================
# WHAT A LINE SAYS, AND THE COLOUR IT TAKES
# ==============================================================================
# A command never names a colour. It says what kind of line this is:
#
#   Write-Host "  Start Docker Desktop, then run this again." -ForegroundColor ([ThemeCli]::GetColor("hint"))
#
# Six kinds are lines - error, warning, success, info, muted, hint - and the
# seventh, danger, is the banner's: a box rather than a line.
#
# The colour is read from the colour scheme of the Windows Terminal profile
# this command runs in: of the two versions a scheme keeps of each colour, the
# one read on its background is used. Where a scheme offers nothing readable
# for a kind, that kind is written in the colour the scheme writes its own text
# in - the one colour it guarantees.
#
# With nothing to read - a console window, VS Code, a test, CI - the sixteen
# names a console has always had are used.
#
# Two doors, and everything else below builds them - hidden: GetColor, the
# colour of a kind, and GetBannerColors, the banner's pair - its box, and the
# ink read on that box, the one question that reads two colours together. A
# class method takes no ValidateSet (measured), so GetColor checks the kind
# itself: an unknown one throws, rather than answering Black in silence.
# ==============================================================================
class ThemeCli {
    # -----------------------------------------------------------------------
    # Where the scheme is read
    # -----------------------------------------------------------------------
    # The files Windows Terminal's profiles are written in - the same three
    # Update-TerminalSettings names when it asks a window to read them again.
    hidden static [string[]]$TerminalSettings = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
    )

    # And the ones this repository writes for its instances: one per instance,
    # by name, layered over the profile WSL made for it.
    hidden static [string]$OurFragments = (Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\wsl-fleet")

    # -----------------------------------------------------------------------
    # Where a scheme keeps the sixteen names
    # -----------------------------------------------------------------------
    # The sixteen names are two versions of eight colours; a scheme writes them
    # one key each, or as a list of sixteen - in ANSI order, which is NOT the
    # order a console numbers them in: red is the second row of the list and
    # the fourth value of [ConsoleColor]. Reading the list by console number
    # would paint every error green, and this table is the only place the two
    # orders meet.
    hidden static [System.Collections.IDictionary]$SlotNames = [ordered]@{
        "Black"       = @{ Key = "black";        Index = 0 }
        "DarkRed"     = @{ Key = "red";          Index = 1 }
        "DarkGreen"   = @{ Key = "green";        Index = 2 }
        "DarkYellow"  = @{ Key = "yellow";       Index = 3 }
        "DarkBlue"    = @{ Key = "blue";         Index = 4 }
        "DarkMagenta" = @{ Key = "purple";       Index = 5 }
        "DarkCyan"    = @{ Key = "cyan";         Index = 6 }
        "Gray"        = @{ Key = "white";        Index = 7 }
        "DarkGray"    = @{ Key = "brightBlack";  Index = 8 }
        "Red"         = @{ Key = "brightRed";    Index = 9 }
        "Green"       = @{ Key = "brightGreen";  Index = 10 }
        "Yellow"      = @{ Key = "brightYellow"; Index = 11 }
        "Blue"        = @{ Key = "brightBlue";   Index = 12 }
        "Magenta"     = @{ Key = "brightPurple"; Index = 13 }
        "Cyan"        = @{ Key = "brightCyan";   Index = 14 }
        "White"       = @{ Key = "brightWhite";  Index = 15 }
    }

    # -----------------------------------------------------------------------
    # The kind of line, and the colour it asks for
    # -----------------------------------------------------------------------
    # What a kind is written in when there is no scheme to read: the names this
    # project used before, which every console resolves its own way.
    hidden static [System.Collections.IDictionary]$WithoutScheme = [ordered]@{
        error   = "Red"
        warning = "Yellow"
        success = "Green"
        info    = "Cyan"
        muted   = "DarkGray"
        hint    = "White"
        danger  = "DarkRed"
    }

    # warning and hint part company here: a warning takes the colour a scheme
    # keeps for cautions; a hint says what to do next and takes the colour that
    # scheme writes its text in.
    hidden static [System.Collections.IDictionary]$FamilyOf = [ordered]@{
        error   = "red"
        warning = "yellow"
        success = "green"
        info    = "cyan"
        muted   = "quiet"
        hint    = "text"
        danger  = "red"
    }

    # The two versions a scheme keeps, named as a console names them. The last
    # one wins a tie - the bright version, the one this project has always
    # used, wherever a scheme gives the two the same value.
    hidden static [System.Collections.IDictionary]$VersionOfColour = [ordered]@{
        red    = @("DarkRed", "Red")
        yellow = @("DarkYellow", "Yellow")
        green  = @("DarkGreen", "Green")
        cyan   = @("DarkCyan", "Cyan")
        text   = @("Gray", "White")
        quiet  = @("DarkGray")
    }

    # Below this a line is not read, it is guessed - so a colour under it is
    # refused and the scheme's text colour is used. It sits under the quiet
    # grey of One Half Dark, the scheme this project has been read in.
    hidden static [double]$UnreadableBelow = 2.0

    # The scheme is read once per command, not once per line: a command prints
    # one line or two hundred, and both cost the same.
    hidden static [bool]$ThemeRead = $false
    hidden static [object]$Theme = $null

    # -----------------------------------------------------------------------
    # The colours
    # -----------------------------------------------------------------------

    # The colour of a kind of line. Every command asks this and nothing else.
    static [ConsoleColor] GetColor([string]$kind) {
        if (-not [ThemeCli]::WithoutScheme.Contains($kind)) {
            throw "Unknown kind '$kind' - one of: $([ThemeCli]::WithoutScheme.Keys -join ', ')."
        }

        $Look = [ThemeCli]::GetTheme()
        if (-not $Look) { return [ConsoleColor]([ThemeCli]::WithoutScheme[$kind]) }

        $Candidates = @([ThemeCli]::VersionOfColour[[ThemeCli]::FamilyOf[$kind]])
        return [ConsoleColor]([ThemeCli]::GetReadableColour($Look, $Look.Background, `
            $Candidates, [ThemeCli]::GetTextColour($Look)))
    }

    # The banner's pair: its box, and the ink read on that box - the scheme's
    # red as background, and whichever of the light names is read on that red,
    # not on the terminal behind it. No theme: the console's dark red, white
    # on it.
    static [object] GetBannerColors() {
        $Box = [ThemeCli]::GetColor("danger")
        $Ink = "White"

        $Look = [ThemeCli]::GetTheme()
        if ($Look) {
            $Ink = [ThemeCli]::GetReadableColour($Look, [ThemeCli]::GetSchemeColour($Look.Scheme, $Box), `
                @("Gray", "White", "Black"), [ThemeCli]::GetTextColour($Look))
        }

        return [PSCustomObject]@{ Box = $Box; Ink = $Ink }
    }

    # The scheme of this window, and nothing when it cannot be read: not in
    # Windows Terminal, a profile with no scheme and no defaults, a scheme no
    # file holds, or a colour missing from it.
    hidden static [object] GetTheme() {
        if ([ThemeCli]::ThemeRead) { return [ThemeCli]::Theme }
        [ThemeCli]::ThemeRead = $true

        $Guid = "$env:WT_PROFILE_ID"
        if (-not $Guid) { return $null }

        $Name = [ThemeCli]::GetWindowColorScheme($Guid)
        if (-not $Name) { return $null }

        $Scheme = [ThemeCli]::GetWindowScheme($Name)
        if (-not $Scheme -or -not $Scheme.background -or -not $Scheme.foreground) { return $null }

        [ThemeCli]::Theme = [PSCustomObject]@{
            Background = "$($Scheme.background)"
            Foreground = "$($Scheme.foreground)"
            Scheme     = $Scheme
        }
        return [ThemeCli]::Theme
    }

    # The scheme the profile we are printing in wears. Windows Terminal names
    # that profile in WT_PROFILE_ID; what it wears is written either in the
    # user's own settings or in the fragment this repository writes for an
    # instance, and a profile that says nothing itself takes the scheme of the
    # profile defaults.
    hidden static [object] GetWindowColorScheme([string]$Guid) {
        $Settings = @()
        foreach ($Path in [ThemeCli]::TerminalSettings) {
            $Parsed = [ThemeCli]::ReadTerminalJson($Path)
            if ($Parsed) { $Settings += $Parsed }
        }

        foreach ($Parsed in $Settings) {
            foreach ($Profile in @($Parsed.profiles.list)) {
                if ("$($Profile.guid)" -eq $Guid -and $Profile.colorScheme) { return "$($Profile.colorScheme)" }
            }
        }

        foreach ($File in @(Get-ChildItem [ThemeCli]::OurFragments -Filter *.json -ErrorAction SilentlyContinue)) {
            $Entry = @(([ThemeCli]::ReadTerminalJson($File.FullName)).profiles)[0]
            if ($Entry -and "$($Entry.updates)" -eq $Guid -and $Entry.colorScheme) { return "$($Entry.colorScheme)" }
        }

        foreach ($Parsed in $Settings) {
            if ($Parsed.profiles.defaults.colorScheme) { return "$($Parsed.profiles.defaults.colorScheme)" }
        }
        return $null
    }

    # The user's own version of the scheme first - they wrote it, and Terminal
    # lets it win - then the one inside Terminal's package. Read last: asking
    # for a package costs a fifth of a second.
    hidden static [object] GetWindowScheme([string]$Name) {
        foreach ($Path in [ThemeCli]::TerminalSettings) {
            $Parsed = [ThemeCli]::ReadTerminalJson($Path)
            foreach ($Scheme in @($Parsed.schemes)) {
                if ($Scheme -and "$($Scheme.name)" -eq $Name) { return $Scheme }
            }
        }

        $Packages = @()
        foreach ($PackageName in @("Microsoft.WindowsTerminal", "Microsoft.WindowsTerminalPreview")) {
            $Packages += @(Get-AppxPackage -Name $PackageName -ErrorAction SilentlyContinue)
        }
        foreach ($Package in $Packages) {
            $Parsed = [ThemeCli]::ReadTerminalJson((Join-Path $Package.InstallLocation "defaults.json"))
            foreach ($Scheme in @($Parsed.schemes)) {
                if ($Scheme -and "$($Scheme.name)" -eq $Name) { return $Scheme }
            }
        }
        return $null
    }

    # One of the sixteen names, as the colour the scheme gives it - by its own
    # key, or by its row in a scheme written as a list.
    hidden static [object] GetSchemeColour($Scheme, [string]$Name) {
        $Where = [ThemeCli]::SlotNames[$Name]
        if (-not $Where -or -not $Scheme) { return $null }
        $Named = $Scheme.($Where.Key)
        if ($Named) { return "$Named" }
        $List = @($Scheme.palette)
        if ($List.Count -ge 16 -and $List[$Where.Index]) { return "$($List[$Where.Index])" }
        return $null
    }

    # The name closest to the colour the scheme writes its own text in - every
    # scheme read here keeps its text colour in one of the sixteen too, so this
    # is a lookup, not a blend.
    hidden static [string] GetTextColour($Look) {
        $Nearest = $null
        $Closest = [double]::MaxValue
        foreach ($Name in [ThemeCli]::SlotNames.Keys) {
            $Hex = [ThemeCli]::GetSchemeColour($Look.Scheme, $Name)
            if (-not $Hex) { continue }
            $Distance = [ThemeCli]::GetColourDistance($Look.Foreground, $Hex)
            if ($Distance -lt $Closest) { $Closest = $Distance; $Nearest = $Name }
        }
        if (-not $Nearest) { return "White" }
        return $Nearest
    }

    # The name of the candidates that is read best on a colour, or the fallback
    # when none of them is read at all.
    hidden static [string] GetReadableColour($Look, [string]$Reference, [string[]]$Candidates, [string]$Fallback) {
        $Best = $null
        $BestRatio = -1
        foreach ($Name in $Candidates) {
            $Hex = [ThemeCli]::GetSchemeColour($Look.Scheme, $Name)
            if (-not $Hex) { continue }
            $Ratio = [ThemeCli]::GetContrastRatio($Reference, $Hex)
            if ($Ratio -ge $BestRatio) { $BestRatio = $Ratio; $Best = $Name }
        }
        if (-not $Best) { return $Fallback }
        if ($BestRatio -lt [ThemeCli]::UnreadableBelow -and $Fallback) { return $Fallback }
        return $Best
    }

    # -----------------------------------------------------------------------
    # What the numbers are
    # -----------------------------------------------------------------------

    # A colour as three numbers, or nothing at all when the text is not a
    # colour: a scheme is a file the user may have edited, and a broken one
    # leaves the terminal's own names in place rather than stopping a command.
    hidden static [object] GetRgb([string]$Hex) {
        $Text = "$Hex".Trim()
        if ($Text.StartsWith("#")) { $Text = $Text.Substring(1) }
        if ($Text.Length -eq 3) { $Text = "$($Text[0])$($Text[0])$($Text[1])$($Text[1])$($Text[2])$($Text[2])" }
        if ($Text.Length -ne 6) { return $null }
        try {
            return @(
                [Convert]::ToInt32($Text.Substring(0, 2), 16),
                [Convert]::ToInt32($Text.Substring(2, 2), 16),
                [Convert]::ToInt32($Text.Substring(4, 2), 16)
            )
        } catch {
            return $null
        }
    }

    # How light a colour is, the way the contrast rule below counts it.
    hidden static [object] GetLuminance([string]$Hex) {
        $Rgb = [ThemeCli]::GetRgb($Hex)
        if (-not $Rgb) { return $null }
        $Channel = {
            param($Value)
            $Part = $Value / 255
            if ($Part -le 0.03928) { return $Part / 12.92 }
            return [Math]::Pow(($Part + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * (& $Channel $Rgb[0]) + 0.7152 * (& $Channel $Rgb[1]) + 0.0722 * (& $Channel $Rgb[2])
    }

    # How far apart two colours are to the eye: 1 is the same colour, 21 is
    # black on white. Anything under 3 is hard to read, and 1 means one of the
    # two is the other - which is what a scheme whose white is its background
    # says.
    hidden static [double] GetContrastRatio([string]$A, [string]$B) {
        $First = [ThemeCli]::GetLuminance($A)
        $Second = [ThemeCli]::GetLuminance($B)
        if ($null -eq $First -or $null -eq $Second) { return 0 }
        if ($First -lt $Second) { $Swap = $First; $First = $Second; $Second = $Swap }
        return [Math]::Round(($First + 0.05) / ($Second + 0.05), 2)
    }

    # How far apart two colours are, counted, not measured: it answers "which
    # of these is the closest one" and nothing else, which is all it is asked.
    hidden static [double] GetColourDistance([string]$A, [string]$B) {
        $First = [ThemeCli]::GetRgb($A)
        $Second = [ThemeCli]::GetRgb($B)
        if (-not $First -or -not $Second) { return [double]::MaxValue }
        $Red = $First[0] - $Second[0]
        $Green = $First[1] - $Second[1]
        $Blue = $First[2] - $Second[2]
        return [double]($Red * $Red + $Green * $Green + $Blue * $Blue)
    }

    # -----------------------------------------------------------------------
    # Reading Windows Terminal's files
    # -----------------------------------------------------------------------
    # Windows Terminal writes JSON with // comments and a comma before a
    # closing bracket; PowerShell's reader refuses both. A blind replace is
    # worse: the file holds a string of every punctuation mark
    # ("wordDelimiters"), and taking a comma out of IT breaks the JSON
    # elsewhere.
    #
    # So the walk below knows what a string is, and a file that still will not
    # parse is no schemes at all, not a crash.
    hidden static [object] ReadTerminalJson([string]$Path) {
        if (-not $Path -or -not (Test-Path $Path)) { return $null }
        try {
            $Text = [System.IO.File]::ReadAllText($Path)
        } catch {
            return $null
        }

        try {
            $Out = New-Object System.Text.StringBuilder
            $InString = $false
            for ($Index = 0; $Index -lt $Text.Length; $Index++) {
                $Char = $Text[$Index]

                if ($InString) {
                    $null = $Out.Append($Char)
                    if ($Char -eq '\') {
                        $Index++
                        if ($Index -lt $Text.Length) { $null = $Out.Append($Text[$Index]) }
                        continue
                    }
                    if ($Char -eq '"') { $InString = $false }
                    continue
                }

                if ($Char -eq '"') { $InString = $true; $null = $Out.Append($Char); continue }

                if ($Char -eq '/' -and ($Index + 1) -lt $Text.Length -and $Text[$Index + 1] -eq '/') {
                    while ($Index -lt $Text.Length -and $Text[$Index] -ne "`n") { $Index++ }
                    $null = $Out.Append("`n")
                    continue
                }

                if ($Char -eq ',') {
                    $Next = $Index + 1
                    while ($Next -lt $Text.Length -and [char]::IsWhiteSpace($Text[$Next])) { $Next++ }
                    if ($Next -lt $Text.Length -and ($Text[$Next] -eq '}' -or $Text[$Next] -eq ']')) { continue }
                }

                $null = $Out.Append($Char)
            }
            return ($Out.ToString() | ConvertFrom-Json)
        } catch {
            return $null
        }
    }
}
