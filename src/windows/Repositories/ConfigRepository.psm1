using module ..\Entities\WpfTheme.psm1

class ConfigRepository {

    hidden [string]$AssetsDir
    hidden [string]$DistroTree

    ConfigRepository([string]$assetsDir) {
        $this.AssetsDir = $assetsDir
        $this.DistroTree = ""
    }

    ConfigRepository([string]$assetsDir, [string]$distroTree) {
        $this.AssetsDir = $assetsDir
        $this.DistroTree = $distroTree
    }

    [string[]] GetThemeNames() {
        $root = Join-Path $this.AssetsDir "themes"
        if (-not (Test-Path $root)) { return @() }
        $names = @()
        foreach ($file in (Get-ChildItem $root -File -Filter *.xaml | Sort-Object Name)) {
            $names += $file.BaseName
        }
        return @($names)
    }

    [string[]] GetFontNames() {
        $fontHome = Join-Path $this.AssetsDir "fonts"
        if (-not (Test-Path $fontHome)) { return @() }

        $names = @()
        foreach ($dir in (Get-ChildItem $fontHome -Directory)) {
            $hasFont = $false
            foreach ($file in (Get-ChildItem $dir.FullName -File)) {
                if ($file.Extension -eq ".ttf" -or $file.Extension -eq ".otf") { $hasFont = $true; break }
            }
            if (-not $hasFont) { continue }

            try {
                Add-Type -AssemblyName PresentationCore
                $mediaFonts = [type]"Windows.Media.Fonts"
                $uri = [Uri]("file:///" + ($dir.FullName -replace '\\', '/') + "/")
                foreach ($family in $mediaFonts::GetFontFamilies($uri)) {
                    if ("$($family.Source)" -like "*Font Awesome*") { continue }
                    $name = "$($family.FamilyNames.Values | Select-Object -First 1)"
                    if (-not $name) { $name = "$($family.Source)" -replace '^\./#', '' }
                    if ($name -and $names -notcontains $name) { $names += $name }
                }
            } catch { }
        }
        return @($names | Sort-Object)
    }

    [string[]] GetPromptFontNames() {
        $fontHome = Join-Path $this.AssetsDir "fonts"
        if (-not (Test-Path $fontHome)) { return @() }

        $names = @()
        foreach ($dir in (Get-ChildItem $fontHome -Directory)) {
            $face = $null
            foreach ($file in (Get-ChildItem $dir.FullName -File)) {
                if ($file.Extension -eq ".ttf" -or $file.Extension -eq ".otf") { $face = $file; break }
            }
            if (-not $face) { continue }

            try {
                Add-Type -AssemblyName PresentationCore
                $glyphType = [type]"Windows.Media.GlyphTypeface"
                $glyphs = $glyphType::new([Uri]("file:///" + ($face.FullName -replace '\\', '/')))
                $map = $glyphs.CharacterToGlyphMap
                if (-not ($map.ContainsKey(0xF07B) -or $map.ContainsKey(0xE0B0))) { continue }

                $mediaFonts = [type]"Windows.Media.Fonts"
                $uri = [Uri]("file:///" + ($dir.FullName -replace '\\', '/') + "/")
                foreach ($family in $mediaFonts::GetFontFamilies($uri)) {
                    if ("$($family.Source)" -like "*Font Awesome*") { continue }
                    $name = "$($family.FamilyNames.Values | Select-Object -First 1)"
                    if (-not $name) { $name = "$($family.Source)" -replace '^\./#', '' }
                    if ($name -and $names -notcontains $name) { $names += $name }
                }
            } catch { }
        }
        return @($names | Sort-Object)
    }

    [object[]] GetDockerfiles() {
        $rows = @($this.ReadDockerfileRows())
        if ($rows.Count -eq 0) {
            $null = $this.WriteSeedRecipe("dockerfiles", "Dockerfile", "Dockerfile", "Dockerfile.dockerignore")
            $rows = @($this.ReadDockerfileRows())
        }
        return @($rows)
    }

    hidden [object[]] ReadDockerfileRows() {
        $rows = @()
        foreach ($row in @($this.ReadSourceRows("dockerfiles", "Dockerfile"))) {
            $rows += [PSCustomObject]@{
                Name     = $row.Name
                Path     = $row.Path
                Modified = $row.Modified
                Family   = $this.ReadRecipeFamily($row.Path)
            }
        }
        return @($rows)
    }

    [string] ReadRecipeFamily([string]$path) {
        if (-not $path -or -not (Test-Path -LiteralPath $path)) { return "" }

        $base = $null
        foreach ($line in @(Get-Content -LiteralPath $path -ErrorAction SilentlyContinue)) {
            if ("$line" -match '^\s*FROM\s+(?:--\S+\s+)*(\S+)') { $base = $Matches[1]; break }
        }
        if (-not $base) { return "" }

        $name = ($base -split '[@:]')[0].ToLower()
        $name = ($name -split '/')[-1]
        if ($name -in @('debian', 'ubuntu', 'linuxmint', 'mint', 'kali', 'pop', 'raspbian',
                        'elementary', 'zorin', 'parrot', 'deepin', 'neon')) {
            return 'debian'
        }
        return $name
    }

    [object[]] GetOnboardings() {
        $rows = @($this.ReadSourceRows("onboardings", "onboarding.sh"))
        if ($rows.Count -eq 0) {
            $null = $this.WriteSeedRecipe("onboardings", "onboarding", "onboarding.sh", "")
            $rows = @($this.ReadSourceRows("onboardings", "onboarding.sh"))
        }
        return @($rows)
    }

    [object[]] GetRecipes() {
        $root = Join-Path $this.AssetsDir "recipes"
        if (-not (Test-Path $root)) { return @() }
        $rows = @()
        foreach ($slot in @(Get-ChildItem $root -Directory)) {
            $rows += [PSCustomObject]@{
                Name     = $slot.Name
                Path     = $slot.FullName
                Modified = $slot.LastWriteTime
                Family   = $this.ReadRecipeFamily((Join-Path $slot.FullName "Dockerfile"))
            }
        }
        return @($rows)
    }

    [string] CreateRecipe([string]$name) {
        $fingerprint = [Guid]::NewGuid().ToString("N").Substring(0, 8)
        $slot = Join-Path (Join-Path $this.AssetsDir "recipes") "$name-$fingerprint"
        $null = New-Item -ItemType Directory -Path $slot -Force
        return $slot
    }

    hidden [void] WriteSeedRecipe([string]$kind, [string]$slot, [string]$fileName, [string]$sibling) {
        if (-not $this.DistroTree) { return }
        $source = Join-Path $this.DistroTree "build\$fileName"
        if (-not (Test-Path -LiteralPath $source)) { return }

        $targetDir = Join-Path (Join-Path $this.AssetsDir $kind) $slot
        $null = New-Item -ItemType Directory -Path $targetDir -Force
        Copy-Item -LiteralPath $source -Destination (Join-Path $targetDir $fileName) -Force
        (Get-Item -LiteralPath (Join-Path $targetDir $fileName)).LastWriteTime = Get-Date

        if ($sibling) {
            $beside = Join-Path (Split-Path $source -Parent) $sibling
            if (Test-Path -LiteralPath $beside) {
                Copy-Item -LiteralPath $beside -Destination (Join-Path $targetDir $sibling) -Force
            }
        }
    }

    hidden [object[]] ReadSourceRows([string]$folder, [string]$file) {
        $root = Join-Path $this.AssetsDir $folder
        if (-not (Test-Path $root)) { return @() }
        $rows = @()
        foreach ($slot in @(Get-ChildItem $root -Directory)) {
            $path = Join-Path $slot.FullName $file
            if (-not (Test-Path $path)) { continue }
            $rows += [PSCustomObject]@{
                Name     = $slot.Name
                Path     = $path
                Modified = (Get-Item -LiteralPath $path).LastWriteTime
            }
        }
        return @($rows)
    }

    [string] CopyRecipe([string]$kind, [string]$source, [string]$fileName) {
        $fingerprint = (Get-FileHash -LiteralPath $source -Algorithm SHA1).Hash.Substring(0, 8).ToLower()
        $slot = Join-Path (Join-Path $this.AssetsDir $kind) ("$([IO.Path]::GetFileNameWithoutExtension($source))-$fingerprint")
        $null = New-Item -ItemType Directory -Path $slot -Force
        $target = Join-Path $slot $fileName
        Copy-Item -LiteralPath $source -Destination $target -Force
        (Get-Item -LiteralPath $target).LastWriteTime = Get-Date
        if ($fileName -eq "Dockerfile") {
            $sibling = Join-Path ([IO.Path]::GetDirectoryName($source)) ".dockerignore"
            if (Test-Path $sibling) {
                Copy-Item -LiteralPath $sibling -Destination (Join-Path $slot "Dockerfile.dockerignore") -Force
            }
        }
        return $target
    }

    [void] RemoveRecipe([string]$path) {
        $slot = [System.IO.Path]::GetFullPath($path)
        if (-not (Test-Path -LiteralPath $slot -PathType Container)) {
            $slot = [System.IO.Path]::GetFullPath((Split-Path -Path $path -Parent))
        }
        $sep = [IO.Path]::DirectorySeparatorChar
        $under = $false
        foreach ($kind in @("dockerfiles", "onboardings", "dockerimages", "recipes")) {
            $root = [System.IO.Path]::GetFullPath((Join-Path $this.AssetsDir $kind))
            if ($slot.StartsWith($root.TrimEnd($sep) + $sep)) { $under = $true; break }
        }
        if (-not $under) { throw "'$slot' is not a recipe slot - nothing was removed." }
        Remove-Item -LiteralPath $slot -Recurse -Force -ErrorAction Stop
    }

    [void] ExportRecipe([string]$path, [string]$target) {
        Copy-Item -LiteralPath $path -Destination $target -Force -ErrorAction Stop
    }

    [string] CopyFont([string]$source) {
        $fingerprint = (Get-FileHash -LiteralPath $source -Algorithm SHA1).Hash.Substring(0, 8).ToLower()
        $slot = Join-Path (Join-Path $this.AssetsDir "fonts") ("$([IO.Path]::GetFileNameWithoutExtension($source))-$fingerprint")
        $null = New-Item -ItemType Directory -Path $slot -Force
        Copy-Item -LiteralPath $source -Destination (Join-Path $slot ([IO.Path]::GetFileName($source))) -Force
        return $slot
    }

    [string] CopyTheme([string]$source) {
        $name = [IO.Path]::GetFileNameWithoutExtension($source)
        $target = Join-Path (Join-Path $this.AssetsDir "themes") "$name.xaml"
        $null = New-Item -ItemType Directory -Path (Split-Path -Path $target -Parent) -Force
        Copy-Item -LiteralPath $source -Destination $target -Force
        return $target
    }

    [void] DeleteTheme([string]$name) {
        $target = Join-Path (Join-Path $this.AssetsDir "themes") "$([IO.Path]::GetFileNameWithoutExtension($name)).xaml"
        if (-not (Test-Path -LiteralPath $target)) { throw "No theme named '$name' lives in the themes folder." }
        Remove-Item -LiteralPath $target -Force -ErrorAction Stop
    }

    [void] OpenTheme([string]$name) {
        $target = Join-Path (Join-Path $this.AssetsDir "themes") "$([IO.Path]::GetFileNameWithoutExtension($name)).xaml"
        if (-not (Test-Path -LiteralPath $target)) { throw "No theme named '$name' lives in the themes folder." }
        Start-Process -FilePath $target -ErrorAction Stop
    }

    [string] GetSavedRoot() {
        $file = $this.RootFile()
        if (-not $file -or -not (Test-Path $file)) { return "" }
        $line = Get-Content -LiteralPath $file -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($line) { return $line.Trim().TrimEnd('\') }
        return ""
    }

    [void] SaveRoot([string]$root) {
        $file = $this.RootFile()
        if (-not $file) { return }
        $null = New-Item -ItemType Directory -Path (Split-Path -Path $file -Parent) -Force
        Set-Content -LiteralPath $file -Value $root.TrimEnd('\') -Encoding utf8NoBOM
    }

    [WpfTheme] GetWpfTheme() {
        $theme = [WpfTheme]::new()
        $path = $this.WpfSettingsFile()
        if (-not (Test-Path $path)) { return $theme }
        try {
            $saved = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
            if ($saved.FontFamily) { $theme.SetFontFamily("$($saved.FontFamily)") }
            if ($saved.FontSize) { $theme.SetFontSize([int]$saved.FontSize) }
            if ($saved.ColourSet) { $theme.SetColorTheme("$($saved.ColourSet)") }
            if ($saved.ColourVariant) { $theme.SetVariant("$($saved.ColourVariant)") }
        } catch { }
        return $theme
    }

    [void] SaveWpfTheme([WpfTheme]$theme) {
        $content = [PSCustomObject]@{
            FontFamily    = $theme.GetFontFamily()
            FontSize      = $theme.GetFontSize()
            ColourSet     = $theme.GetColorTheme()
            ColourVariant = $theme.GetVariant()
        }
        $path = $this.WpfSettingsFile()
        $null = New-Item -ItemType Directory -Path (Split-Path -Path $path -Parent) -Force
        $content | ConvertTo-Json | Set-Content -LiteralPath $path -Encoding utf8NoBOM
    }

    [string] EnsureWslConfig() {
        $path = Join-Path $env:USERPROFILE ".wslconfig"
        if (-not (Test-Path $path)) {
            @'
# WSL's Windows-wide settings. Read when the WSL machine starts: `wsl --shutdown`
# then a new start applies a change.
#
# The common keys: https://learn.microsoft.com/windows/wsl/wsl-config
#
# [wsl2]
# memory=8GB          # the machine's memory cap
# processors=4        # the CPUs it may use
# dnsTunneling=true   # WSL answers the DNS itself
'@ | Set-Content -Path $path -Encoding ascii
        }
        return $path
    }

    hidden [string] RootFile() {
        if (-not $env:LOCALAPPDATA) { return "" }
        return (Join-Path $env:LOCALAPPDATA "wsl-fleet\root.txt")
    }

    hidden [string] WpfSettingsFile() {
        return (Join-Path $env:LOCALAPPDATA "wsl-fleet\gui-settings.json")
    }
}
