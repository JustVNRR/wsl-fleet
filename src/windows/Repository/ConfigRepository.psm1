# ==============================================================================
# LE DÉPÔT DE LA CONFIGURATION
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout un type qu'il a tiré
# lui-même.
using module ..\Model\WpfTheme.psm1

# L'appli propre et le foyer Windows : root.txt (la racine de la flotte, lue et
# écrite — la règle, elle, vit sur FleetService.GetRoot), gui-settings.json (le
# look de la fenêtre, lu et écrit — les règles, elles, vivent sur WpfService),
# ~/.wslconfig, son gabarit écrit quand il manque, et les dossiers de l'appli
# — les thèmes de la fenêtre et les polices qu'elle livre, sous les assets.
# Aucune règle ici : lire et écrire, rien de plus. Les chemins se lisent de
# l'environnement, au moment de l'appel ; le dossier des assets se tient à la
# construction.
class ConfigRepository {
    hidden [string]$AssetsDir

    ConfigRepository([string]$assetsDir) {
        $this.AssetsDir = $assetsDir
    }

    # Les thèmes que la fenêtre peut porter : les fichiers sous assets\themes,
    # par leur nom — chacun porte ses versions sombre et claire. Un fichier
    # posé là est un thème de plus.
    [string[]] GetThemeNames() {
        $root = Join-Path $this.AssetsDir "themes"
        if (-not (Test-Path $root)) { return @() }
        $names = @()
        foreach ($file in (Get-ChildItem $root -File -Filter *.xaml | Sort-Object Name)) {
            $names += $file.BaseName
        }
        return @($names)
    }

    # Les familles que le dossier des polices porte, par leur nom de famille —
    # lu sur les fichiers (les dossiers sont des emplacements, pas des noms),
    # un dossier par face, les livrées et celles ajoutées. Windows seul sait
    # le dire ; une machine qui ne peut pas lit une liste vide.
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
                # Le type par son nom : un littéral [Windows.Media.Fonts]
                # serait résolu quand ce fichier se charge, et une machine sans
                # WPF ne le charge alors même pas.
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

    # Les Dockerfiles que la naissance peut prendre : un sous-dossier de
    # assets\dockerfiles, son fichier dedans — un dossier sans fichier n'est
    # pas une source, un dossier absent n'est pas une erreur. Le brut : le nom
    # du dossier tel quel, le chemin, la date du fichier, et la famille lue au
    # premier FROM (le repli des dérivées de Debian compris — c'est la lecture
    # qui décide quels packs la checklist offre) ; la mise en forme d'écran se
    # fait au service.
    [object[]] GetDockerfiles() {
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

    # La famille d'un Dockerfile, lue à son premier FROM : les dérivées de
    # Debian connues répondent "debian" (le repli que os-release appliquera),
    # toute autre base répond son nom, et un fichier illisible — ou un FROM
    # caché derrière un ARG — répond "" : inconnue, qui ne filtre rien.
    [string] ReadRecipeFamily([string]$path) {
        if (-not $path -or -not (Test-Path -LiteralPath $path)) { return "" }

        $base = $null
        foreach ($line in @(Get-Content -LiteralPath $path -ErrorAction SilentlyContinue)) {
            # --platform and friends ride in front of the image name.
            if ("$line" -match '^\s*FROM\s+(?:--\S+\s+)*(\S+)') { $base = $Matches[1]; break }
        }
        if (-not $base) { return "" }

        # registry/path/image:tag@digest -> the image name alone.
        $name = ($base -split '[@:]')[0].ToLower()
        $name = ($name -split '/')[-1]
        if ($name -in @('debian', 'ubuntu', 'linuxmint', 'mint', 'kali', 'pop', 'raspbian',
                        'elementary', 'zorin', 'parrot', 'deepin', 'neon')) {
            return 'debian'
        }
        return $name
    }

    # Les onboardings de même : assets\onboardings\<dossier>\onboarding.sh.
    [object[]] GetOnboardings() {
        return @($this.ReadSourceRows("onboardings", "onboarding.sh"))
    }

    # Les lignes d'un dossier de sources — une par sous-dossier qui porte son
    # fichier. Rien n'est trié ni formaté ici.
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

    # Un fichier recopié dans un emplacement de recette —
    # assets\<kind>\<nom>-<empreinte>\ — sous le nom que le bâtisseur y lit
    # (Dockerfile, onboarding.sh, ou le tar tel quel). L'empreinte (SHA1,
    # huit signes) est celle du contenu : le même fichier deux fois ne fait
    # pas deux emplacements, un modifié en fait un autre. Un Dockerfile
    # emmène son .dockerignore d'à côté, sous le nom qu'un bâtisseur lit
    # auprès d'un -f Dockerfile. Rend le chemin posé.
    [string] CopyRecipe([string]$kind, [string]$source, [string]$fileName) {
        $fingerprint = (Get-FileHash -LiteralPath $source -Algorithm SHA1).Hash.Substring(0, 8).ToLower()
        $slot = Join-Path (Join-Path $this.AssetsDir $kind) ("$([IO.Path]::GetFileNameWithoutExtension($source))-$fingerprint")
        $null = New-Item -ItemType Directory -Path $slot -Force
        $target = Join-Path $slot $fileName
        Copy-Item -LiteralPath $source -Destination $target -Force
        if ($fileName -eq "Dockerfile") {
            $sibling = Join-Path ([IO.Path]::GetDirectoryName($source)) ".dockerignore"
            if (Test-Path $sibling) {
                Copy-Item -LiteralPath $sibling -Destination (Join-Path $slot "Dockerfile.dockerignore") -Force
            }
        }
        return $target
    }

    # Un emplacement de recette ôté — son dossier entier, et rien d'autre.
    # Le chemin doit vivre sous les dossiers des recettes : un chemin venu
    # d'ailleurs jette — on n'efface pas un dossier quelconque.
    [void] RemoveRecipe([string]$path) {
        $slot = [System.IO.Path]::GetFullPath((Split-Path -Path $path -Parent))
        $sep = [IO.Path]::DirectorySeparatorChar
        $under = $false
        foreach ($kind in @("dockerfiles", "onboardings", "dockerimages")) {
            $root = [System.IO.Path]::GetFullPath((Join-Path $this.AssetsDir $kind))
            if ($slot.StartsWith($root.TrimEnd($sep) + $sep)) { $under = $true; break }
        }
        if (-not $under) { throw "'$slot' is not a recipe slot - nothing was removed." }
        Remove-Item -LiteralPath $slot -Recurse -Force -ErrorAction Stop
    }

    # Une recette rendue où l'utilisateur pointe — le téléchargement : la
    # copie vers la cible, la source intacte.
    [void] ExportRecipe([string]$path, [string]$target) {
        Copy-Item -LiteralPath $path -Destination $target -Force -ErrorAction Stop
    }

    # Une police recopiée dans un dossier à elle sous assets\fonts —
    # <nom>-<empreinte>\<le fichier> : le dossier porte l'identité du
    # contenu (le même fichier deux fois n'en fait pas deux ; un modifié
    # prend un chemin que le cache de polices n'a jamais vu — mesuré : il
    # sert sinon les octets anciens). Rend le dossier posé.
    [string] CopyFont([string]$source) {
        $fingerprint = (Get-FileHash -LiteralPath $source -Algorithm SHA1).Hash.Substring(0, 8).ToLower()
        $slot = Join-Path (Join-Path $this.AssetsDir "fonts") ("$([IO.Path]::GetFileNameWithoutExtension($source))-$fingerprint")
        $null = New-Item -ItemType Directory -Path $slot -Force
        Copy-Item -LiteralPath $source -Destination (Join-Path $slot ([IO.Path]::GetFileName($source))) -Force
        return $slot
    }

    # Un thème recopié sous assets\themes, sous le nom de son fichier — un
    # thème, c'est son fichier. Un nom déjà pris s'écrase : le prompt l'a
    # confirmé. Rend le chemin posé.
    [string] CopyTheme([string]$source) {
        $name = [IO.Path]::GetFileNameWithoutExtension($source)
        $target = Join-Path (Join-Path $this.AssetsDir "themes") "$name.xaml"
        $null = New-Item -ItemType Directory -Path (Split-Path -Path $target -Parent) -Force
        Copy-Item -LiteralPath $source -Destination $target -Force
        return $target
    }

    # Le fichier d'un thème ôté — par son nom. Un nom que le dossier ne
    # porte pas jette : on n'efface pas au hasard.
    [void] DeleteTheme([string]$name) {
        $target = Join-Path (Join-Path $this.AssetsDir "themes") "$([IO.Path]::GetFileNameWithoutExtension($name)).xaml"
        if (-not (Test-Path -LiteralPath $target)) { throw "No theme named '$name' lives in the themes folder." }
        Remove-Item -LiteralPath $target -Force -ErrorAction Stop
    }

    # Le fichier d'un thème ouvert comme Windows ouvre les fichiers.
    [void] OpenTheme([string]$name) {
        $target = Join-Path (Join-Path $this.AssetsDir "themes") "$([IO.Path]::GetFileNameWithoutExtension($name)).xaml"
        if (-not (Test-Path -LiteralPath $target)) { throw "No theme named '$name' lives in the themes folder." }
        Start-Process -FilePath $target -ErrorAction Stop
    }

    # La racine que le fichier garde — la première ligne, vide quand le
    # fichier n'est pas là. Sans %LOCALAPPDATA% (les bacs à sable de
    # certaines suites), il n'y a pas de mémoire : vide aussi.
    [string] GetSavedRoot() {
        $file = $this.RootFile()
        if (-not $file -or -not (Test-Path $file)) { return "" }
        $line = Get-Content -LiteralPath $file -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($line) { return $line.Trim().TrimEnd('\') }
        return ""
    }

    # Le choix écrit pour les prochaines courses.
    [void] SaveRoot([string]$root) {
        $file = $this.RootFile()
        if (-not $file) { return }
        $null = New-Item -ItemType Directory -Path (Split-Path -Path $file -Parent) -Force
        Set-Content -LiteralPath $file -Value $root.TrimEnd('\') -Encoding utf8NoBOM
    }

    # Le look de la fenêtre, lu — les défauts d'aujourd'hui, puis ce que le
    # fichier en dit. Un fichier illisible laisse les défauts.
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

    # Le look écrit — les mêmes clés que le fichier d'aujourd'hui, sans BOM.
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

    # Le ~/.wslconfig : son gabarit écrit quand il manque — un fichier à
    # quelqu'un n'est jamais touché — et son chemin rendu, pour l'ouverture.
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

    # --- les chemins ------------------------------------------------------------

    # Le fichier de la racine : hors du dossier de travail par nécessité — le
    # dossier ne peut pas dire où il est.
    hidden [string] RootFile() {
        if (-not $env:LOCALAPPDATA) { return "" }
        return (Join-Path $env:LOCALAPPDATA "wsl-stack\root.txt")
    }

    hidden [string] WpfSettingsFile() {
        return (Join-Path $env:LOCALAPPDATA "wsl-stack\gui-settings.json")
    }
}
