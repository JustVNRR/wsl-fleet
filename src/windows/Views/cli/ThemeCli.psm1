class ThemeCli {
    hidden static [string[]]$TerminalSettings = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
    )

    hidden static [string]$OurFragments = (Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\wsl-fleet")

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

    hidden static [System.Collections.IDictionary]$WithoutScheme = [ordered]@{
        error   = "Red"
        warning = "Yellow"
        success = "Green"
        info    = "Cyan"
        muted   = "DarkGray"
        hint    = "White"
        danger  = "DarkRed"
    }

    hidden static [System.Collections.IDictionary]$FamilyOf = [ordered]@{
        error   = "red"
        warning = "yellow"
        success = "green"
        info    = "cyan"
        muted   = "quiet"
        hint    = "text"
        danger  = "red"
    }

    hidden static [System.Collections.IDictionary]$VersionOfColour = [ordered]@{
        red    = @("DarkRed", "Red")
        yellow = @("DarkYellow", "Yellow")
        green  = @("DarkGreen", "Green")
        cyan   = @("DarkCyan", "Cyan")
        text   = @("Gray", "White")
        quiet  = @("DarkGray")
    }

    hidden static [double]$UnreadableBelow = 2.0

    hidden static [bool]$ThemeRead = $false
    hidden static [object]$Theme = $null

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

    hidden static [object] GetSchemeColour($Scheme, [string]$Name) {
        $Where = [ThemeCli]::SlotNames[$Name]
        if (-not $Where -or -not $Scheme) { return $null }
        $Named = $Scheme.($Where.Key)
        if ($Named) { return "$Named" }
        $List = @($Scheme.palette)
        if ($List.Count -ge 16 -and $List[$Where.Index]) { return "$($List[$Where.Index])" }
        return $null
    }

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

    hidden static [double] GetContrastRatio([string]$A, [string]$B) {
        $First = [ThemeCli]::GetLuminance($A)
        $Second = [ThemeCli]::GetLuminance($B)
        if ($null -eq $First -or $null -eq $Second) { return 0 }
        if ($First -lt $Second) { $Swap = $First; $First = $Second; $Second = $Swap }
        return [Math]::Round(($First + 0.05) / ($Second + 0.05), 2)
    }

    hidden static [double] GetColourDistance([string]$A, [string]$B) {
        $First = [ThemeCli]::GetRgb($A)
        $Second = [ThemeCli]::GetRgb($B)
        if (-not $First -or -not $Second) { return [double]::MaxValue }
        $Red = $First[0] - $Second[0]
        $Green = $First[1] - $Second[1]
        $Blue = $First[2] - $Second[2]
        return [double]($Red * $Red + $Green * $Green + $Blue * $Blue)
    }

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
