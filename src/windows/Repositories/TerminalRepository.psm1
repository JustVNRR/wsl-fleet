using module ..\Entities\WslTheme.psm1

class TerminalRepository {
    hidden [string]$AssetsDir

    TerminalRepository([string]$assetsDir) {
        $this.AssetsDir = $assetsDir
    }

    [string] GetFragmentPath([string]$instanceName) {
        return (Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\wsl-fleet\$instanceName.json")
    }

    [bool] HasFragment([string]$instanceName) {
        return (Test-Path $this.GetFragmentPath($instanceName))
    }

    [void] SaveFragment([string]$instanceName, [string]$guid, [WslTheme]$theme) {
        $fragmentDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\wsl-fleet"
        $null = New-Item -ItemType Directory -Force $fragmentDir
        $iconPath = $theme.GetIconPath()
        $iconJson = if ($iconPath -and (Test-Path $iconPath)) {
            '            "icon": "' + ($iconPath -replace '\\', '\\') + '",'
        } else {
            ''
        }
        $fragmentJson = @"
{
    "profiles": [
        {
            "updates": "$guid",
$iconJson
            "font": { "face": "$($theme.GetFontName())" },
            "colorScheme": "$($theme.GetColorScheme())",
            "suppressApplicationTitle": true
        }
    ]
}
"@
        [System.IO.File]::WriteAllText($this.GetFragmentPath($instanceName), $fragmentJson,
            (New-Object System.Text.UTF8Encoding($false)))
    }

    [void] DeleteFragment([string]$instanceName) {
        Remove-Item -LiteralPath $this.GetFragmentPath($instanceName) -Force -ErrorAction SilentlyContinue
    }

    [string] GetProfileGuid([string]$instanceName) {
        for ($attempt = 1; $attempt -le 5; $attempt++) {
            $guid = $this.ReadProfileGuid($instanceName)
            if ($guid) { return $guid }
            Start-Sleep -Seconds 1
        }
        return ""
    }

    [bool] HasWslProfile([string]$instanceName) {
        return [bool]($this.ReadProfileGuid($instanceName))
    }

    [object] GetWslGuids([string]$instanceName) {
        $folder = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\Microsoft.WSL"
        $live = @()
        $match = ""
        if (Test-Path $folder) {
            foreach ($file in (Get-ChildItem $folder -Filter *.json | Sort-Object LastWriteTime -Descending)) {
                try {
                    foreach ($entry in (Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json).profiles) {
                        if ($entry.guid) { $live += "$($entry.guid)" }
                        if (-not $match -and $instanceName -and $entry.name -eq $instanceName -and $entry.guid) {
                            $match = "$($entry.guid)"
                        }
                    }
                } catch { }
            }
        }
        return [PSCustomObject]@{ Guids = @($live); Guid = $match }
    }

    hidden [string] ReadProfileGuid([string]$instanceName) {
        return ($this.GetWslGuids($instanceName).Guid)
    }

    [object] PruneGhostEntries([string]$instanceName, [string[]]$liveGuids) {
        $pruned = 0
        $unreadable = @()
        foreach ($settingsPath in @(
            "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
            "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
            "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
        )) {
            if (-not (Test-Path $settingsPath)) { continue }
            try {
                $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
                $all = @($settings.profiles.list)
                $kept = @()
                foreach ($profile in $all) {
                    if ($profile.source -eq "Microsoft.WSL" -and $profile.name -eq $instanceName -and
                        $liveGuids -notcontains "$($profile.guid)") { continue }
                    $kept += $profile
                }
                if ($kept.Count -ne $all.Count) {
                    Copy-Item $settingsPath "$settingsPath.bak" -Force
                    $settings.profiles.list = $kept
                    $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding Utf8
                    $pruned += ($all.Count - $kept.Count)
                }
            } catch {
                $unreadable += $settingsPath
            }
        }
        return [PSCustomObject]@{ Pruned = $pruned; Unreadable = @($unreadable) }
    }

    [string[]] RemoveStaleFragments([string[]]$liveGuids) {
        $removed = @()
        if (@($liveGuids).Count -eq 0) { return @() }
        $ours = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\wsl-fleet"
        if (-not (Test-Path $ours)) { return @() }
        foreach ($file in (Get-ChildItem $ours -Filter *.json)) {
            try {
                $fragment = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
                $target = ""
                foreach ($entry in @($fragment.profiles)) {
                    if ($entry.updates) { $target = "$($entry.updates)"; break }
                }
                if ($target -and ($liveGuids -notcontains $target)) {
                    Remove-Item $file.FullName -Force
                    $removed += $file.Name
                }
            } catch { }
        }
        return @($removed)
    }

    [void] TouchSettings() {
        foreach ($path in @(
            "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
            "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
            "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
        )) {
            if (Test-Path $path) { (Get-Item -LiteralPath $path).LastWriteTime = (Get-Date) }
        }
    }

    [WslTheme] GetAppearance([string]$instanceName) {
        $theme = [WslTheme]::Default($instanceName)

        $fragment = $this.GetFragmentPath($instanceName)
        if (Test-Path $fragment) {
            try {
                $parsed = (Get-Content -LiteralPath $fragment -Raw | ConvertFrom-Json).profiles[0]
                if ($parsed.font.face) { $theme.SetFont("$($parsed.font.face)") }
                if ($parsed.colorScheme) { $theme.SetColourScheme("$($parsed.colorScheme)") }
            } catch { }
        }

        foreach ($settingsPath in @(
            "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
            "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
            "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
        )) {
            if (-not (Test-Path $settingsPath)) { continue }
            try {
                foreach ($profile in (Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json).profiles.list) {
                    if ($profile.name -eq $instanceName -and $profile.source -eq "Microsoft.WSL") {
                        if ($profile.font.face) { $theme.SetFont("$($profile.font.face)") }
                        if ($profile.colorScheme) { $theme.SetColourScheme("$($profile.colorScheme)") }
                    }
                }
            } catch { }
        }

        return $theme
    }

    [object[]] GetColorSchemes() {
        $schemes = @{}

        foreach ($packageName in @("Microsoft.WindowsTerminal", "Microsoft.WindowsTerminalPreview")) {
            try {
                foreach ($package in @(Get-AppxPackage -Name $packageName -ErrorAction SilentlyContinue)) {
                    $parsed = $this.ReadTerminalJson((Join-Path $package.InstallLocation "defaults.json"))
                    foreach ($scheme in @($parsed.schemes)) {
                        if ($scheme -and $scheme.name -and -not $schemes.ContainsKey("$($scheme.name)")) {
                            $schemes["$($scheme.name)"] = $scheme
                        }
                    }
                }
            } catch { }
        }

        foreach ($settingsPath in @(
            "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
            "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
            "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
        )) {
            $parsed = $this.ReadTerminalJson($settingsPath)
            foreach ($scheme in @($parsed.schemes)) {
                if ($scheme -and $scheme.name) { $schemes["$($scheme.name)"] = $scheme }
            }
        }

        $ours = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\wsl-fleet"
        foreach ($file in @(Get-ChildItem $ours -Filter *.json -ErrorAction SilentlyContinue)) {
            $parsed = $this.ReadTerminalJson($file.FullName)
            $named = @($parsed.profiles)[0].colorScheme
            if ($named -and -not $schemes.ContainsKey("$named")) { $schemes["$named"] = $null }
        }

        $slots = @(
            @{ Name = "Black";       Key = "black";        Index = 0 },
            @{ Name = "DarkRed";     Key = "red";          Index = 1 },
            @{ Name = "DarkGreen";   Key = "green";        Index = 2 },
            @{ Name = "DarkYellow";  Key = "yellow";       Index = 3 },
            @{ Name = "DarkBlue";    Key = "blue";         Index = 4 },
            @{ Name = "DarkMagenta"; Key = "purple";       Index = 5 },
            @{ Name = "DarkCyan";    Key = "cyan";         Index = 6 },
            @{ Name = "Gray";        Key = "white";        Index = 7 },
            @{ Name = "DarkGray";    Key = "brightBlack";  Index = 8 },
            @{ Name = "Red";         Key = "brightRed";    Index = 9 },
            @{ Name = "Green";       Key = "brightGreen";  Index = 10 },
            @{ Name = "Yellow";      Key = "brightYellow"; Index = 11 },
            @{ Name = "Blue";        Key = "brightBlue";   Index = 12 },
            @{ Name = "Magenta";     Key = "brightPurple"; Index = 13 },
            @{ Name = "Cyan";        Key = "brightCyan";   Index = 14 },
            @{ Name = "White";       Key = "brightWhite";  Index = 15 }
        )

        $rows = @()
        foreach ($name in @($schemes.Keys | Sort-Object)) {
            $scheme = $schemes[$name]
            $block = [ordered]@{
                Name       = "$name"
                Background = ""
                Foreground = ""
            }
            if ($scheme) {
                $block.Background = "$($scheme.background)"
                $block.Foreground = "$($scheme.foreground)"
            }
            foreach ($slot in $slots) {
                $colour = ""
                if ($scheme) {
                    $named = $scheme.($slot.Key)
                    if ($named) {
                        $colour = "$named"
                    } else {
                        $palette = @($scheme.palette)
                        if ($palette.Count -ge 16 -and $palette[$slot.Index]) { $colour = "$($palette[$slot.Index])" }
                    }
                }
                $block[$slot.Name] = $colour
            }
            $rows += [PSCustomObject]$block
        }
        return @($rows)
    }

    hidden [object] ReadTerminalJson([string]$path) {
        if (-not $path -or -not (Test-Path $path)) { return $null }
        try {
            $text = Get-Content -LiteralPath $path -Raw
        } catch {
            return $null
        }

        try {
            $out = New-Object System.Text.StringBuilder
            $inString = $false
            for ($index = 0; $index -lt $text.Length; $index++) {
                $char = $text[$index]

                if ($inString) {
                    $null = $out.Append($char)
                    if ($char -eq '\') {
                        $index++
                        if ($index -lt $text.Length) { $null = $out.Append($text[$index]) }
                        continue
                    }
                    if ($char -eq '"') { $inString = $false }
                    continue
                }

                if ($char -eq '"') { $inString = $true; $null = $out.Append($char); continue }

                if ($char -eq '/' -and ($index + 1) -lt $text.Length -and $text[$index + 1] -eq '/') {
                    while ($index -lt $text.Length -and $text[$index] -ne "`n") { $index++ }
                    $null = $out.Append("`n")
                    continue
                }

                if ($char -eq ',') {
                    $next = $index + 1
                    while ($next -lt $text.Length -and [char]::IsWhiteSpace($text[$next])) { $next++ }
                    if ($next -lt $text.Length -and ($text[$next] -eq '}' -or $text[$next] -eq ']')) { continue }
                }

                $null = $out.Append($char)
            }
            return ($out.ToString() | ConvertFrom-Json)
        } catch {
            return $null
        }
    }

    [bool] IsFontInstalled([string]$faceName) {
        $fontRegPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
        return [bool](Get-ItemProperty -Path $fontRegPath -Name "$faceName (TrueType)" -ErrorAction SilentlyContinue)
    }

    [void] InstallFont([string]$faceName, [string]$from) {
        $fontRegPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
        $userFontsDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
        $dest = Join-Path $userFontsDir "$faceName Regular.ttf"

        if (-not (Test-Path $fontRegPath)) { $null = New-Item -Path $fontRegPath -Force }
        if (-not (Test-Path $userFontsDir)) { $null = New-Item -ItemType Directory -Path $userFontsDir -Force }

        $tempPath = Join-Path $env:TEMP "$([guid]::NewGuid().ToString('N')).ttf"
        try {
            $source = $from
            if (-not $source -or -not (Test-Path $source)) {
                $source = $this.FindBundledFont($faceName)
            }
            if (-not $source) {
                Invoke-WebRequest -Uri "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf" -OutFile $tempPath -UseBasicParsing
                $source = $tempPath
            }
            if (-not (Test-Path $dest)) { Copy-Item -Path $source -Destination $dest -Force }
            if (-not (Get-ItemProperty -Path $fontRegPath -Name "$faceName (TrueType)" -ErrorAction SilentlyContinue)) {
                $null = New-ItemProperty -Path $fontRegPath -Name "$faceName (TrueType)" -Value $dest -PropertyType String -Force
            }
        } finally {
            Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
        }
    }

    hidden [string] FindBundledFont([string]$faceName) {
        $root = Join-Path $this.AssetsDir "fonts"
        if (-not (Test-Path $root)) { return "" }
        foreach ($file in (Get-ChildItem -Path $root -Recurse -File -ErrorAction SilentlyContinue)) {
            if (($file.Extension -eq ".ttf" -or $file.Extension -eq ".otf") -and $file.Name -like "$faceName*") {
                return $file.FullName
            }
        }
        return ""
    }

    [object[]] GetTerminalFonts() {
        Add-Type -AssemblyName System.Drawing
        $familyType = [type]"System.Drawing.FontFamily"

        $folderGlyph = 0xF07B
        $arrowGlyph = 0xE0B0

        $styles = @("Regular", "Bold", "Italic", "Oblique", "Light", "SemiLight", "Medium",
                    "Thin", "Black", "Heavy", "SemiBold", "Semibold", "DemiBold", "ExtraBold",
                    "ExtraLight", "UltraLight", "Book", "Condensed", "Narrow")

        $symbolFonts = @("Wingdings", "Wingdings 2", "Wingdings 3", "Webdings", "Symbol", "Marlett")

        $files = $this.FontFiles()
        $families = @()
        foreach ($family in $familyType::Families) { $families += $family.Name }
        $families = @($families | Sort-Object)

        $fonts = @()
        foreach ($family in $families) {
            $base = $family
            foreach ($style in $styles) {
                if ($family -like "* $style") {
                    $base = $family.Substring(0, $family.Length - $style.Length - 1)
                    break
                }
            }
            if ($base -ne $family -and $families -contains $base) { continue }
            if (-not $this.TestMonospace($family)) { continue }
            if ($symbolFonts -contains $family) { continue }

            $glyphs = $this.FontGlyphMap($files, $family)

            if ($glyphs -and -not $glyphs.ContainsKey([int][char]"A")) { continue }

            $hasIcons = if ($glyphs) { $glyphs.ContainsKey($folderGlyph) -or $glyphs.ContainsKey($arrowGlyph) } else { $null }
            $fonts += [PSCustomObject]@{ Name = $family; Icons = $hasIcons }
        }

        $usable = @()
        foreach ($font in $fonts) {
            if ($font.Icons -eq $true) { $usable += $font }
        }
        return @($usable | Sort-Object Name)
    }

    hidden [hashtable] FontFiles() {
        $files = @{}
        foreach ($root in @("HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts",
                            "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts")) {
            $key = Get-ItemProperty -Path $root -ErrorAction SilentlyContinue
            if (-not $key) { continue }
            foreach ($property in $key.psobject.properties) {
                $face = ($property.Name -replace '\s*\(TrueType\)\s*$', '').Trim()
                if (-not $face -or $files.ContainsKey($face)) { continue }
                $path = [string]$property.Value
                if (-not [System.IO.Path]::IsPathRooted($path)) { $path = Join-Path $env:WINDIR "Fonts\$path" }
                $files[$face] = $path
            }
        }
        return $files
    }

    hidden [object] FontGlyphMap([hashtable]$files, [string]$family) {
        $path = $null
        if ($files.ContainsKey($family)) { $path = $files[$family] }
        if (-not $path) {
            foreach ($face in $files.Keys) {
                if ($face -like "$family *") { $path = $files[$face]; break }
            }
        }
        if (-not $path -or -not (Test-Path $path)) { return $null }

        try {
            Add-Type -AssemblyName PresentationCore
            $typeface = New-Object Windows.Media.GlyphTypeface (New-Object System.Uri $path)
            return ,$typeface.CharacterToGlyphMap
        } catch {
            return $null
        }
    }

    hidden [bool] TestMonospace([string]$family) {
        $font = $null
        $bitmap = $null
        $canvas = $null
        try {
            $formatType = [type]"System.Drawing.StringFormat"
            $graphicsType = [type]"System.Drawing.Graphics"
            $font = New-Object System.Drawing.Font($family, 20)
            $format = $formatType::GenericTypographic
            $bitmap = New-Object System.Drawing.Bitmap(64, 64)
            $canvas = $graphicsType::FromImage($bitmap)
            $narrow = $canvas.MeasureString("iiii", $font, 1000, $format).Width
            $wide = $canvas.MeasureString("WWWW", $font, 1000, $format).Width
            return ([Math]::Abs($narrow - $wide) -lt 0.05)
        } catch {
            return $false
        } finally {
            if ($canvas) { $canvas.Dispose() }
            if ($bitmap) { $bitmap.Dispose() }
            if ($font) { $font.Dispose() }
        }
    }

    [object] DrawIcon([string]$instanceName, [string]$outputPath, [object]$drawing) {
        $arguments = @{
            Name  = $instanceName
            Out   = $outputPath
            Quiet = $true
            What  = $true
        }
        if ($drawing) {
            foreach ($key in @("Text", "Top", "Bottom", "TextColor")) {
                $value = "$($drawing.$key)"
                if ($value) { $arguments[$key] = $value }
            }
        }

        $script = Join-Path $PSScriptRoot "..\Tools\make-icon.ps1"
        $answer = & $script @arguments | ConvertFrom-Json
        return [PSCustomObject]@{
            Text      = "$($answer.Text)"
            Top       = "$($answer.Top)"
            Bottom    = "$($answer.Bottom)"
            TextColor = "$($answer.TextColor)"
        }
    }

    [object[]] GetIconPairs() {
        $script = Join-Path $PSScriptRoot "..\Tools\make-icon.ps1"
        $rows = @()
        foreach ($line in @(& $script -ListPairs)) {
            if (-not "$line") { continue }
            $field = "$line" -split "`t"
            $rows += [PSCustomObject]@{
                Name      = "$($field[0])"
                Top       = "$($field[1])"
                Bottom    = "$($field[2])"
                TextColor = "$($field[3])"
            }
        }
        return @($rows)
    }
}
