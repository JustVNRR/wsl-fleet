using module ..\Entities\WslInstance.psm1
using module .\InstanceRepository.psm1

class ArchiveRepository {

    hidden [string]$ArchivesRoot
    hidden [InstanceRepository]$Files

    ArchiveRepository([string]$archivesRoot) {
        $this.ArchivesRoot = $archivesRoot
        $this.Files = [InstanceRepository]::new($archivesRoot)
    }

    [void] ReRoot([string]$root) {
        $this.ArchivesRoot = Join-Path $root "archives"
        $this.Files.ReRoot($this.ArchivesRoot)
    }

    [string] GetFolder([string]$archiveName) {
        return (Join-Path $this.ArchivesRoot $archiveName)
    }

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

    [string] GetTar([string]$archiveName) {
        $tar = Get-ChildItem -Path $this.GetFolder($archiveName) -Filter "*.tar*" -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($tar) { return $tar.FullName }
        return ""
    }

    [long] GetTarSize([string]$archiveName) {
        $tar = $this.GetTar($archiveName)
        if ($tar) { return [long](Get-Item -LiteralPath $tar).Length }
        return 0
    }

    [datetime] GetCreatedAt([string]$archiveName) {
        $folder = $this.GetFolder($archiveName)
        if (-not (Test-Path $folder)) { return [datetime]::MinValue }
        return (Get-Item -LiteralPath $folder).LastWriteTime
    }

    [WslInstance] GetInstance([string]$archiveName) {
        $archive = $this.Files.GetInstance($archiveName)
        $archive.SetIsArchive($true)
        return $archive
    }

    [void] SaveInstance([WslInstance]$archive, [string]$docker) {
        $this.Files.SaveInstance($archive, $docker)
    }

    [string] GetDocker([string]$archiveName) {
        return ($this.Files.GetSavedDocker($archiveName))
    }

    [void] EnsureFolder([string]$archiveName) {
        $null = New-Item -ItemType Directory -Path $this.GetFolder($archiveName) -Force
    }

    [bool] HasArchive([string]$archiveName) {
        return (Test-Path $this.GetFolder($archiveName))
    }

    [string] GetIconPath([string]$archiveName) {
        return (Join-Path $this.GetFolder($archiveName) "terminal-icon.png")
    }

    [bool] HasIcon([string]$archiveName) {
        return (Test-Path $this.GetIconPath($archiveName))
    }

    [void] SaveIcon([string]$archiveName, [string]$source) {
        Copy-Item -LiteralPath $source -Destination $this.GetIconPath($archiveName) -Force
    }

    [void] DeleteArchive([string]$archiveName) {
        $folder = $this.GetFolder($archiveName)
        if (-not (Test-Path $folder)) {
            throw "There is no archive named '$archiveName': $folder does not exist."
        }
        Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction Stop
    }

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

        & robocopy.exe $this.ArchivesRoot $newArchives /E /COPY:DAT /Z /R:3 /W:2 | Out-Null
        $code = $global:LASTEXITCODE
        if ($code -ge 8) {
            throw "robocopy reported errors (code $code) - the originals are untouched."
        }
    }
}
