# ==============================================================================
# LE DÉPÔT DES INSTANCES
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout un type qu'il a tiré
# lui-même.
using module ..\Entities\WslInstance.psm1
using module ..\Entities\WslTheme.psm1

# Le dossier d'une instance, sur le disque : son fichier instance.json (le
# user, le thème), son icône, son marqueur, et ce que le dossier dit tout seul
# — la taille du vhdx, sa date de création. Aucune règle ici : lire et écrire,
# rien de plus. Le dossier se résout par le nom — la racine tenue par la
# construction + le nom.
class InstanceRepository {
    hidden [string]$InstancesRoot

    InstanceRepository([string]$instancesRoot) {
        $this.InstancesRoot = $instancesRoot
    }

    # La racine redite — le migrate l'a déplacée : le dépôt suit, sans être
    # reconstruit.
    [void] ReRoot([string]$root) {
        $this.InstancesRoot = $root
    }

    [string] GetFolder([string]$name) {
        return (Join-Path $this.InstancesRoot $name)
    }

    # Le fichier de l'instance, lu — le user et le thème qu'il porte. Le nom
    # vient de la demande, pas du fichier ; rien d'autre n'est deviné ici. Un
    # fichier absent ou illisible : un modèle nu, pas une erreur — la
    # prochaine écriture le remplacera.
    [WslInstance] GetInstance([string]$name) {
        $instance = [WslInstance]::new()
        $instance.SetName($name)
        $file = Join-Path $this.GetFolder($name) "instance.json"
        if (-not (Test-Path $file)) { return $instance }
        try {
            $saved = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
        } catch {
            return $instance
        }
        if ($saved.DefaultUser) { $instance.SetDefaultUser("$($saved.DefaultUser)") }
        if ($saved.Theme) {
            $theme = [WslTheme]::new()
            if ($saved.Theme.Font) { $theme.SetFont("$($saved.Theme.Font)") }
            if ($saved.Theme.ColorScheme) { $theme.SetColourScheme("$($saved.Theme.ColorScheme)") }
            if ($saved.Theme.IconFrom) { $theme.SetIconPath("$($saved.Theme.IconFrom)") }
            $theme.SetIcon([PSCustomObject]@{
                Text      = "$($saved.Theme.IconText)"
                Top       = "$($saved.Theme.IconTop)"
                Bottom    = "$($saved.Theme.IconBottom)"
                TextColor = "$($saved.Theme.IconTextColor)"
            })
            $instance.SetTheme($theme)
        }
        return $instance
    }

    # L'instance écrite — le user et le thème, dans son fichier. Le nom n'est
    # pas écrit : le dossier le porte. Le dessin vide ne laisse pas quatre
    # lignes derrière lui, comme aujourd'hui. La réponse que Docker Desktop
    # donnait se dit quand l'appelant en porte une : une archive garde la
    # sienne (son originale peut disparaître), une instance vivante se demande
    # en direct, et son fichier reste sans la ligne.
    [void] SaveInstance([WslInstance]$instance, [string]$docker) {
        $theme = $instance.GetTheme()
        if ($null -eq $theme) { $theme = [WslTheme]::new() }

        $block = [ordered]@{
            Font        = "$($theme.GetFontName())"
            ColorScheme = "$($theme.GetColorScheme())"
            IconFrom    = "$($theme.GetIconPath())"
        }
        $icon = $theme.GetIcon()
        if ($icon.Text) {
            $block.IconText      = "$($icon.Text)"
            $block.IconTop       = "$($icon.Top)"
            $block.IconBottom    = "$($icon.Bottom)"
            $block.IconTextColor = "$($icon.TextColor)"
        }

        $content = [ordered]@{
            DefaultUser = "$($instance.GetDefaultUser())"
            Theme       = [PSCustomObject]$block
        }
        if ($docker) { $content.Docker = $docker }
        $content | ConvertTo-Json -Depth 4 |
            Set-Content -LiteralPath (Join-Path $this.GetFolder($instance.GetName()) "instance.json") -Encoding utf8NoBOM
    }

    # La réponse Docker Desktop qu'un fichier porte — vide quand le fichier
    # n'en dit rien (une instance vivante) ou n'existe pas.
    [string] GetSavedDocker([string]$name) {
        $file = Join-Path $this.GetFolder($name) "instance.json"
        if (-not (Test-Path $file)) { return "" }
        try { $saved = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json } catch { return "" }
        return "$($saved.Docker)"
    }

    # L'image prend le siège de l'icône : le fichier copié sur
    # terminal-icon.png. Le dessin derrière, lui, vit dans le thème.
    [void] SaveIcon([string]$name, [string]$source) {
        Copy-Item -LiteralPath $source -Destination (Join-Path $this.GetFolder($name) "terminal-icon.png") -Force
    }

    # Le marqueur : le fichier qui dit « faite par ce dépôt ». Écrit tout de
    # suite après l'import, avant que quoi que ce soit d'autre ne puisse
    # échouer. Sans BOM, comme le fichier de Docker Desktop : PowerShell's
    # -Encoding Utf8 en colle un que le lecteur d'après n'attend pas.
    [void] WriteMarker([string]$name, [string]$by) {
        $folder = $this.GetFolder($name)
        if (-not (Test-Path $folder)) { return }
        # [ordered] : un hashtable imprimerait ses clés dans un ordre qui
        # change d'une fois à l'autre.
        $marker = [ordered]@{
            template = "wsl-stack"
            created  = (Get-Date).ToString("yyyy-MM-dd")
            by       = $by
        }
        $json = ($marker | ConvertTo-Json) -replace "`r`n", "`n"
        [System.IO.File]::WriteAllText((Join-Path $folder ".wsl-stack"), $json,
            (New-Object System.Text.UTF8Encoding($false)))
    }

    [bool] HasMarker([string]$name) {
        return $this.HasMarkerIn($this.GetFolder($name))
    }

    # Le marqueur, demandé sur un dossier quelconque — la règle de la racine
    # cherche une inscrite là où le registre dit qu'elle vit.
    [bool] HasMarkerIn([string]$folder) {
        if (-not $folder) { return $false }
        return (Test-Path (Join-Path $folder ".wsl-stack"))
    }

    # Les dossiers du foyer qui portent le marqueur, par leur nom — ce que la
    # racine tient, que le registre les revendique ou non.
    [string[]] GetMarkedFolders() {
        $names = @()
        if (-not (Test-Path $this.InstancesRoot)) { return @() }
        foreach ($dir in (Get-ChildItem -Path $this.InstancesRoot -Directory -ErrorAction SilentlyContinue | Sort-Object Name)) {
            if (Test-Path (Join-Path $dir.FullName ".wsl-stack")) { $names += $dir.Name }
        }
        return @($names)
    }

    # La taille du disque, en octets — zéro quand il n'y en a pas.
    [long] GetVhdxSize([string]$name) {
        $vhdx = Join-Path $this.GetFolder($name) "ext4.vhdx"
        if (Test-Path $vhdx) { return [long](Get-Item -LiteralPath $vhdx).Length }
        return 0
    }

    # Le siège de l'icône : terminal-icon.png, dans le dossier. Le dépôt copie
    # dessus (SaveIcon), l'outil de dessin écrit dedans, Terminal la lit.
    [string] GetIconPath([string]$name) {
        return (Join-Path $this.GetFolder($name) "terminal-icon.png")
    }

    [bool] HasIcon([string]$name) {
        return (Test-Path $this.GetIconPath($name))
    }

    # Le dossier existe-t-il déjà, et porte-t-il quelque chose ? La naissance
    # refuse un dossier occupé — un dossier vide, lui, est à personne.
    [bool] IsFolderOccupied([string]$name) {
        $folder = $this.GetFolder($name)
        return (Test-Path $folder) -and (@(Get-ChildItem -Path $folder -Force).Count -gt 0)
    }

    # Ce qui reste du dossier après un désenregistrement — wsl --unregister
    # retire le disque, l'exception est ici. Sans erreur quand il n'y a rien.
    [void] RemoveFolder([string]$name) {
        Remove-Item -LiteralPath $this.GetFolder($name) -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Un dossier qui doit exister — l'arrivée d'un déménagement, par exemple.
    # Rien n'est effacé : un dossier déjà là reste tel quel ; un chemin
    # impossible jette.
    [void] EnsureFolder([string]$folder) {
        $null = New-Item -ItemType Directory -Path $folder -Force -ErrorAction Stop
    }

    # La place libre sur le disque d'un chemin — le refus d'un archivage ou
    # d'une copie se lit ici, avant que quoi que ce soit écrive.
    [long] GetFreeSpace([string]$path) {
        # Le volume par sa racine : la lettre de lecteur n'existe que sur
        # Windows, et un hôte qui n'en a pas jetait ici.
        $full = [System.IO.Path]::GetFullPath($path)
        $volume = New-Object System.IO.DriveInfo([System.IO.Path]::GetPathRoot($full))
        return [long]$volume.AvailableFreeSpace
    }

    # La date de création : celle du dossier.
    [datetime] GetCreatedAt([string]$name) {
        $folder = $this.GetFolder($name)
        if (-not (Test-Path $folder)) { return [datetime]::MinValue }
        return (Get-Item -LiteralPath $folder).CreationTime
    }
}
