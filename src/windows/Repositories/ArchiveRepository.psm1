# ==============================================================================
# LE DÉPÔT DES ARCHIVES
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout un type qu'il a tiré
# lui-même.
using module ..\Entities\WslInstance.psm1
using module .\InstanceRepository.psm1

# Le dossier des archives, sur le disque : une archive par dossier — le tar
# dedans, et l'instance.json à côté (le look gardé, la réponse de Docker
# Desktop avec), la même forme qu'une instance, écrite par le même dépôt. Le
# listage, les tailles, les dossiers, la suppression, le déplacement — le
# migrate. Aucune règle ici : lire et écrire, rien de plus. La racine se tient
# à la construction ; le dossier se résout par le nom — suffixé (wagon →
# wagon_archive), la convention des archives.
class ArchiveRepository {
    hidden [string]$ArchivesRoot
    hidden [InstanceRepository]$Files

    ArchiveRepository([string]$archivesRoot) {
        $this.ArchivesRoot = $archivesRoot
        $this.Files = [InstanceRepository]::new($archivesRoot)
    }

    # La racine redite — la racine de la FLOTTE, comme au constructeur : le
    # dossier des archives ET le dépôt des fichiers qui vit dedans suivent.
    [void] ReRoot([string]$root) {
        $this.ArchivesRoot = Join-Path $root "archives"
        $this.Files.ReRoot($this.ArchivesRoot)
    }

    [string] GetFolder([string]$archiveName) {
        return (Join-Path $this.ArchivesRoot $archiveName)
    }

    # Le listage : chaque dossier qui porte un tar, en instance à l'arrêt —
    # IsArchive vrai. Un dossier sans tar n'est pas une archive ; un nom que
    # la classe refuse est laissé dehors.
    [WslInstance[]] GetAllArchives() {
        $archives = @()
        if (-not (Test-Path $this.ArchivesRoot)) { return @() }
        foreach ($dir in (Get-ChildItem -Path $this.ArchivesRoot -Directory | Sort-Object Name)) {
            $archive = [WslInstance]::new()
            try { $archive.SetName($dir.Name) } catch { continue }
            $archive.SetIsArchive($true)
            if (-not $this.GetTar($dir.Name)) { continue }
            $archives += $archive
        }
        return @($archives)
    }

    # Le tar de l'archive — le plus récent *.tar* du dossier. Une seule
    # orthographe : l'import, les listes et les tailles lisent tous ici. Vide
    # quand le dossier n'en porte aucun.
    [string] GetTar([string]$archiveName) {
        $tar = Get-ChildItem -Path $this.GetFolder($archiveName) -Filter "*.tar*" -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($tar) { return $tar.FullName }
        return ""
    }

    # Ce que l'archive pèse : son tar.
    [long] GetTarSize([string]$archiveName) {
        $tar = $this.GetTar($archiveName)
        if ($tar) { return [long](Get-Item -LiteralPath $tar).Length }
        return 0
    }

    # La date que les listes montrent, à côté de la taille : celle du dossier.
    [datetime] GetCreatedAt([string]$archiveName) {
        $folder = $this.GetFolder($archiveName)
        if (-not (Test-Path $folder)) { return [datetime]::MinValue }
        return (Get-Item -LiteralPath $folder).LastWriteTime
    }

    # L'instance.json à côté du tar — le même fichier qu'une instance, écrit
    # par le même dépôt : le look de l'archivée, gardé. Rendue archive, elle.
    [WslInstance] GetInstance([string]$archiveName) {
        $archive = $this.Files.GetInstance($archiveName)
        $archive.SetIsArchive($true)
        return $archive
    }

    # L'archive écrite — le look et la réponse de Docker Desktop, qui voyagent
    # avec elle : la restauration les relit, l'originale peut avoir disparu.
    [void] SaveInstance([WslInstance]$archive, [string]$docker) {
        $this.Files.SaveInstance($archive, $docker)
    }

    # La réponse que l'archive porte sur Docker Desktop — vide quand elle n'en
    # dit rien.
    [string] GetDocker([string]$archiveName) {
        return ($this.Files.GetSavedDocker($archiveName))
    }

    # Le dossier de l'archive, créé — la racine avec lui quand il naît. Un
    # archivage écrase : l'appelant a retiré la précédente, ou c'est la
    # première.
    [void] EnsureFolder([string]$archiveName) {
        $null = New-Item -ItemType Directory -Path $this.GetFolder($archiveName) -Force
    }

    [bool] HasArchive([string]$archiveName) {
        return (Test-Path $this.GetFolder($archiveName))
    }

    # Le siège de l'icône dans l'archive — la même convention qu'une instance,
    # le dossier change seul.
    [string] GetIconPath([string]$archiveName) {
        return (Join-Path $this.GetFolder($archiveName) "terminal-icon.png")
    }

    [bool] HasIcon([string]$archiveName) {
        return (Test-Path $this.GetIconPath($archiveName))
    }

    [void] SaveIcon([string]$archiveName, [string]$source) {
        Copy-Item -LiteralPath $source -Destination $this.GetIconPath($archiveName) -Force
    }

    # L'archive ôtée : son dossier, entier — le tar, le look et la réponse
    # avec.
    [void] DeleteArchive([string]$archiveName) {
        $folder = $this.GetFolder($archiveName)
        if (-not (Test-Path $folder)) {
            throw "There is no archive named '$archiveName': $folder does not exist."
        }
        Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction Stop
    }

    # Le dossier des archives déplacé, entier — le migrate. Un renommage quand
    # la cible est sur le même volume : rien ne se copie. Sinon robocopy, après
    # la place vérifiée (la copie a besoin de ce que les archives pèsent, plus
    # un souffle), et les originales restent — la racine d'après se réécrit à
    # côté (ConfigRepository), pas ici. Rien à déplacer n'est pas une erreur.
    [void] MoveTo([string]$target) {
        if (-not (Test-Path $this.ArchivesRoot)) { return }

        $targetFull = [System.IO.Path]::GetFullPath($target)
        $newArchives = Join-Path $targetFull "archives"
        if (Test-Path $newArchives) {
            throw "'$newArchives' already exists - nothing was moved. Move it away first."
        }

        $sourceRoot = [System.IO.Path]::GetPathRoot($this.ArchivesRoot)
        $targetRoot = [System.IO.Path]::GetPathRoot($targetFull)
        if ($sourceRoot.TrimEnd('\').ToUpperInvariant() -eq $targetRoot.TrimEnd('\').ToUpperInvariant()) {
            try {
                Move-Item -LiteralPath $this.ArchivesRoot -Destination $newArchives -ErrorAction Stop
            } catch {
                throw "the move failed: $($_.Exception.Message)"
            }
            return
        }

        $archivesSize = (Get-ChildItem -Path $this.ArchivesRoot -Recurse -Force -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
        $free = (Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$($targetRoot.TrimEnd('\'))'").FreeSpace
        if ($free -lt ($archivesSize + 2GB)) {
            throw "not enough free space on '$($targetRoot.TrimEnd('\'))' - $([Math]::Ceiling(($archivesSize + 2GB) / 1GB)) GB needed."
        }

        # /E les sous-dossiers, /COPY:DAT données, attributs et dates, /Z
        # reprenable (une longue copie survit à un hoquet), /R:3 /W:2 une
        # reprise courte. Les codes sous 8 sont la réussite — l'échelle de
        # l'outil, lue du global (une méthode de classe ne voit pas les
        # automatiques de l'appelant).
        & robocopy.exe $this.ArchivesRoot $newArchives /E /COPY:DAT /Z /R:3 /W:2 | Out-Null
        $code = $global:LASTEXITCODE
        if ($code -ge 8) {
            throw "robocopy reported errors (code $code) - the originals are untouched."
        }
    }
}
