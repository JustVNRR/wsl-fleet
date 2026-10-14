# ==============================================================================
# LE DÉPÔT DE WINDOWS TERMINAL
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout un type qu'il a tiré
# lui-même.
using module ..\Model\WslTheme.psm1

# Windows Terminal, sur la machine : nos fragments (le profil posé au-dessus de
# celui de WSL, jamais dans le settings.json de l'utilisateur), le guid que WSL
# a donné à une distribution et le ménage des fantômes — les entrées de
# l'utilisateur et nos fragments dont le guid ne vit plus — la touche qui fait
# relire le settings.json, les jeux de couleurs que la machine peut porter,
# les polices — le registre Windows, l'installation, celles qu'un terminal
# peut porter — et le look lu tel que Windows le montre. Le dossier des assets
# se tient à la construction : c'est lui qui livre la police embarquée, et
# l'outil de dessin vit dans Tools\ (make-icon.ps1, que personne ne
# recopie). Aucune règle ici : lire et écrire, rien de plus.
class TerminalRepository {
    hidden [string]$AssetsDir

    TerminalRepository([string]$assetsDir) {
        $this.AssetsDir = $assetsDir
    }

    # =========================================================================
    # LES FRAGMENTS
    # =========================================================================

    # Notre dossier de fragments : un fichier par instance.
    [string] GetFragmentPath([string]$instanceName) {
        return (Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\wsl-stack\$instanceName.json")
    }

    [bool] HasFragment([string]$instanceName) {
        return (Test-Path $this.GetFragmentPath($instanceName))
    }

    # Le profil que ce dépôt écrit : posé au-dessus de celui de WSL via
    # "updates" — le settings.json de l'utilisateur n'est jamais touché. La
    # ligne de l'icône s'omet quand il n'y a pas d'icône. L'écriture est sans
    # BOM : une marque ne fait pas partie d'un JSON.
    [void] SaveFragment([string]$instanceName, [string]$guid, [WslTheme]$theme) {
        $fragmentDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\wsl-stack"
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

    # =========================================================================
    # LE PROFIL QUE WSL A DONNÉ
    # =========================================================================

    # Le guid que WSL donne à la distribution : Terminal l'écrit dans son
    # propre fragment (Microsoft.WSL), nommé comme la distribution. Le dossier
    # est relu quelques fois — WSL l'écrit une seconde après le démarrage.
    [string] GetProfileGuid([string]$instanceName) {
        for ($attempt = 1; $attempt -le 5; $attempt++) {
            $guid = $this.ReadProfileGuid($instanceName)
            if ($guid) { return $guid }
            Start-Sleep -Seconds 1
        }
        return ""
    }

    # Le même guid, une seule passe — la question rapide d'une ouverture de
    # shell, qui n'attend pas après un profil qui n'arrive pas.
    [bool] HasWslProfile([string]$instanceName) {
        return [bool]($this.ReadProfileGuid($instanceName))
    }

    # Les guids que Terminal peut encore atteindre : chaque fragment que WSL
    # écrit à un import en porte — tout autre guid dans les fichiers de
    # l'utilisateur est un fantôme — et celui de ce nom vient du fragment le
    # plus récent qui le nomme. Une seule passe : l'ouverture rapide s'en sert,
    # et la naissance aussi (elle n'attend pas après un profil qui n'arrive
    # pas — c'est GetProfileGuid qui réessaie).
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

    # =========================================================================
    # LE MÉNAGE DES FANTÔMES
    # =========================================================================

    # Le settings.json de l'utilisateur garde une entrée de profil pour chaque
    # distribution que Terminal a vue ; une reconstruction ou une suppression
    # orpheline l'ancien guid, et l'entrée ne pointe plus sur rien. Les entrées
    # de ce nom dont aucun fragment ne porte le guid s'en vont — le fichier
    # sauvegardé d'abord. Rend ce qui fut retiré, et les fichiers qu'il n'a pas
    # pu lire : un // commentaire casse ConvertFrom-Json, et c'est ça.
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

    # Nos fragments d'apparence dont le guid visé n'existe plus : la
    # distribution est partie et le fichier ne pointe sur rien. Rend les noms
    # retirés. Sans rien de vivant à comparer, rien n'est retiré du tout.
    [string[]] RemoveStaleFragments([string[]]$liveGuids) {
        $removed = @()
        if (@($liveGuids).Count -eq 0) { return @() }
        $ours = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\wsl-stack"
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

    # La touche : rien n'est écrit dans le settings.json de Terminal — sa date
    # seule bouge, et c'est tout ce que son guetteur regarde.
    [void] TouchSettings() {
        foreach ($path in @(
            "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
            "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
            "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
        )) {
            if (Test-Path $path) { (Get-Item -LiteralPath $path).LastWriteTime = (Get-Date) }
        }
    }

    # =========================================================================
    # LE LOOK, TEL QUE WINDOWS LE MONTRE
    # =========================================================================

    # Ce que Windows Terminal montre pour cette instance : notre fragment
    # d'abord (ce que la naissance a posé), ce que le settings.json de
    # l'utilisateur en dit ensuite (ce qu'il a changé depuis), les défauts du
    # dépôt dessous — dans cet ordre. Un settings.json que Terminal possède
    # peut porter des // commentaires, que ConvertFrom-Json refuse : c'est ce
    # que le try attrape. Le siège de l'icône n'est pas ici — il vit dans le
    # dossier de l'instance, et le service le pose.
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

    # =========================================================================
    # LES JEUX DE COULEURS
    # =========================================================================

    # Tous les jeux de couleurs que cette machine peut porter, en lignes
    # plates : le nom, le fond, le texte, et les seize couleurs qu'un
    # programme demande par leur nom — la couleur nommée d'abord, sinon sa
    # place dans la palette. Trois sources, dans cet ordre : ce que Terminal
    # livre (le defaults.json de son paquet), ce que l'utilisateur a ajouté ou
    # écrit par-dessus (ses settings.json — sa version d'un nom gagne), et les
    # noms que nos propres fragments portent — en laisser un dehors cacherait
    # le schéma que l'instance porte maintenant. La console et la fenêtre
    # peignent leurs aperçus avec, une seule lecture pour les deux.
    [object[]] GetColorSchemes() {
        $schemes = @{}

        # Un paquet à la fois : un tableau tendu à -Name se lie à un paramètre
        # qui n'en prend qu'un, et l'appel est refusé avant de courir. Une
        # machine sans la surface Appx n'offre que ce que les settings disent.
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

        $ours = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\wsl-stack"
        foreach ($file in @(Get-ChildItem $ours -Filter *.json -ErrorAction SilentlyContinue)) {
            $parsed = $this.ReadTerminalJson($file.FullName)
            $named = @($parsed.profiles)[0].colorScheme
            if ($named -and -not $schemes.ContainsKey("$named")) { $schemes["$named"] = $null }
        }

        # Les seize noms, et où chaque schéma les garde : sa propre clé, ou sa
        # place dans la palette — l'ordre ANSI, qui n'est PAS l'ordre d'un
        # [ConsoleColor].
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

    # Le JSON de Terminal tel que ses lecteurs doivent le voir : ses fichiers
    # peuvent porter des // commentaires, que ConvertFrom-Json refuse. Le
    # commentaire est retiré — jamais l'intérieur d'une chaîne — et une
    # virgule qui traîne avant une fermeture aussi. $null quand rien ne se
    # lit : l'appelant garde ce qu'il avait.
    hidden [object] ReadTerminalJson([string]$path) {
        if (-not $path -or -not (Test-Path $path)) { return $null }
        try {
            # Par Get-Content : les chemins du dépôt s'écrivent avec des
            # antislashs, et un lecteur .NET ne les prend pas pour des
            # séparateurs là où l'appli tourne ailleurs que sur Windows.
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

    # =========================================================================
    # LES POLICES
    # =========================================================================

    # La police installée pour cet utilisateur : le registre la nomme par la
    # face ("MesloLGS NF (TrueType)") — Windows seul.
    [bool] IsFontInstalled([string]$faceName) {
        $fontRegPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
        return [bool](Get-ItemProperty -Path $fontRegPath -Name "$faceName (TrueType)" -ErrorAction SilentlyContinue)
    }

    # L'installation : le fichier copié dans les polices de l'utilisateur, et
    # son entrée au registre. Un fichier donné gagne — et quand l'appelant n'en
    # donne pas, le dépôt livre le sien (les fichiers sous assets\fonts) ; sans
    # rien dans le dépôt, la police se télécharge. Échoue en jetant : l'appelant
    # décide si c'est grave.
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

    # La police que le dépôt embarque, par sa face : le premier fichier des
    # assets qui commence par elle. Vide quand le dépôt n'en porte pas — la
    # copie a alors le téléchargement pour repli.
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

    # Les familles qu'un terminal peut porter, mesurées sur la machine : celles
    # qui portent le glyphe du dossier ou la flèche powerline — offertes par
    # GDI+ plutôt que lues au registre, et sondées sur le fichier plutôt que
    # devinées par leur nom : une police sans les glyphes du prompt dessine une
    # boîte là où le dossier devrait être. Le console et la fenêtre lisent
    # cette liste, une seule fois l'une comme l'autre.
    [object[]] GetTerminalFonts() {
        # Les types par leur nom : un littéral [System.Drawing.FontFamily]
        # serait résolu quand ce fichier se charge, et une machine sans GDI+
        # ne le chargerait alors même pas.
        Add-Type -AssemblyName System.Drawing
        $familyType = [type]"System.Drawing.FontFamily"

        # Les glyphes dont un prompt se dessine : le dossier, et la flèche
        # powerline qui dit qu'une police fut faite pour un terminal. L'un ou
        # l'autre suffit à l'offrir.
        $folderGlyph = 0xF07B
        $arrowGlyph = 0xE0B0

        # Les styles d'une famille sont des familles à part pour GDI+ — et un
        # profil prend la famille : un nom qui est une autre famille plus un
        # mot de style est laissé dehors, et rien d'autre ne l'est.
        $styles = @("Regular", "Bold", "Italic", "Oblique", "Light", "SemiLight", "Medium",
                    "Thin", "Black", "Heavy", "SemiBold", "Semibold", "DemiBold", "ExtraBold",
                    "ExtraLight", "UltraLight", "Book", "Condensed", "Narrow")

        # Les polices à symboles que Windows livre sous ses propres noms :
        # monospaced, donc gardées par le test d'en dessous, et pleines de
        # glyphes de la zone privée, donc trouvées par celui d'après.
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

            # Une police sans un A capital est une police à symboles, elle
            # aussi — celles de Windows, empilées : monospaced, et sa zone
            # privée lui donne l'air de porter chaque icône. Un prompt écrit
            # dedans est une ligne de boîtes.
            if ($glyphs -and -not $glyphs.ContainsKey([int][char]"A")) { continue }

            $hasIcons = if ($glyphs) { $glyphs.ContainsKey($folderGlyph) -or $glyphs.ContainsKey($arrowGlyph) } else { $null }
            $fonts += [PSCustomObject]@{ Name = $family; Icons = $hasIcons }
        }

        # Seules celles où un prompt peut s'écrire, et rien n'est marqué à
        # côté — une police dont le fichier ne se lit pas sort aussi : ce n'est
        # pas la même réponse que « n'en porte aucune ».
        $usable = @()
        foreach ($font in $fonts) {
            if ($font.Icons -eq $true) { $usable += $font }
        }
        return @($usable | Sort-Object Name)
    }

    # =========================================================================
    # LES PAS PARTAGÉS DES POLICES
    # =========================================================================

    # Les clés du registre nomment chaque fichier par la face qu'il porte —
    # "MesloLGS NF Regular (TrueType)" — donc une passe donne face -> fichier.
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

    # Quels glyphes cette famille porte, lus sur le fichier lui-même : un
    # caractère que la police n'a pas se résout au glyphe zéro — la boîte.
    # Mesuré, pas deviné en cherchant de l'encre où le glyphe devrait être :
    # une boîte a de l'encre aussi. $null quand le fichier ne se lit pas —
    # ce n'est pas la même réponse que « aucun glyphe ».
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
            # La virgule : un dictionnaire écrit vers le pipeline est déroulé
            # en ses entrées, et l'appelant recevrait une paire sans ContainsKey.
            return ,$typeface.CharacterToGlyphMap
        } catch {
            return $null
        }
    }

    # Une police de terminal est monospaced, mesurée plutôt que supposée —
    # 'i' et 'W' prennent la même place — et c'est ce qui garde la liste
    # lisible : Windows porte quelques centaines de polices, la plupart pour
    # lire de la prose.
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

    # =========================================================================
    # L'OUTIL DE DESSIN
    # =========================================================================

    # L'icône dessinée : make-icon.ps1 — l'outil de Tools\, autonome (il ne
    # dépend de rien), que personne ne recopie — écrit le PNG au chemin donné
    # (le dossier de l'instance, son siège) et rend la recette qu'il a
    # dessinée : les lettres et les trois couleurs, relues plus tard pour ne
    # changer qu'une part. Le dessin donné à quatre champs corrige la
    # recette ; nu, l'outil dessine à partir du nom et de ses couleurs à lui.
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

    # La table des paires de la tuile — make-icon.ps1 la porte, et c'est le
    # même script qui dessine : la table et le dessin ne peuvent pas diverger.
    # Une ligne par paire, le brut (nom, haut, bas, couleur du texte).
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
