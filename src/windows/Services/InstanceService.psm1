using module ..\Entities\WslInstance.psm1
using module ..\Entities\WslTheme.psm1
using module ..\Entities\WslPack.psm1
using module ..\Entities\WslPackCatalog.psm1
using module ..\Dtos\InstanceDto.psm1
using module ..\Dtos\DockerDto.psm1
using module ..\Repositories\InstanceRepository.psm1
using module ..\Repositories\ArchiveRepository.psm1
using module ..\Repositories\WslRepository.psm1
using module ..\Repositories\TerminalRepository.psm1
using module ..\Repositories\DockerRepository.psm1
using module ..\Repositories\PackCatalogRepository.psm1
using module ..\Repositories\ConfigRepository.psm1
using module ..\Mappers\InstanceMapper.psm1
using module ..\Tools\Helpers.psm1

class InstanceService {

    hidden [InstanceRepository]$Instances
    hidden [ArchiveRepository]$Archives
    hidden [WslRepository]$Wsl
    hidden [TerminalRepository]$Terminal
    hidden [DockerRepository]$Docker
    hidden [PackCatalogRepository]$Packs
    hidden [ConfigRepository]$Config
    hidden [InstanceMapper]$Map

    InstanceService([InstanceRepository]$instances, [ArchiveRepository]$archives, [WslRepository]$wsl,
                    [TerminalRepository]$terminal, [DockerRepository]$docker, [PackCatalogRepository]$packs,
                    [ConfigRepository]$config) {
        $this.Instances = $instances
        $this.Archives = $archives
        $this.Wsl = $wsl
        $this.Terminal = $terminal
        $this.Docker = $docker
        $this.Packs = $packs
        $this.Config = $config
        $this.Map = [InstanceMapper]::new()
    }

    [void] ReRoot([string]$root) {
        $this.Instances.ReRoot($root)
        $this.Archives.ReRoot($root)
    }

    [WslIndexDto[]] GetAll() {
        $rows = @()

        $dockerNames = $this.Docker.GetDesktopNames()

        foreach ($distro in @($this.Wsl.GetAllDistros())) {
            $name = $distro.GetName()
            if (-not $this.Instances.HasMarker($name)) { continue }
            $distro.SetSize($this.Instances.GetVhdxSize($name))
            $row = $this.Map.ToIndexDto($distro)
            $row.Docker = if ($null -eq $dockerNames) { "unknown" }
                          elseif ($dockerNames -contains $name) { "yes" }
                          else { "no" }
            $row.Path = $this.Instances.GetFolder($name)
            $rows += $row
        }

        foreach ($archive in @($this.Archives.GetAllArchives())) {
            $archive.SetSize($this.Archives.GetTarSize($archive.GetName()))
            $row = $this.Map.ToIndexDto($archive)
            $row.Path = $this.Archives.GetFolder($archive.GetName())
            $row.Archived = $this.Archives.GetCreatedAt($archive.GetName()).ToString("yyyy-MM-dd HH:mm")
            $rows += $row
        }

        return @($rows)
    }

    [WslIndexDto] GetByName([string]$name) {
        foreach ($distro in @($this.Wsl.GetAllDistros())) {
            if ($distro.GetName() -ne $name) { continue }
            if (-not $this.Instances.HasMarker($name)) { return $null }
            $distro.SetSize($this.Instances.GetVhdxSize($name))
            return $this.Map.ToIndexDto($distro)
        }

        foreach ($archive in @($this.Archives.GetAllArchives())) {
            if ($archive.GetName() -ne $name) { continue }
            $archive.SetSize($this.Archives.GetTarSize($name))
            return $this.Map.ToIndexDto($archive)
        }

        return $null
    }

    [WslOrphanDto[]] GetOrphans() {
        $claimed = @()
        foreach ($distro in @($this.Wsl.GetAllDistros())) {
            $folder = $this.Wsl.GetFolder($distro.GetName())
            if (-not $folder) { continue }
            if (-not $this.Instances.HasMarkerIn($folder)) { continue }
            $claimed += $folder.TrimEnd('\')
        }

        $rows = @()
        foreach ($name in @($this.Instances.GetMarkedFolders())) {
            if ($claimed -contains $this.Instances.GetFolder($name)) { continue }
            $dto = [WslOrphanDto]::new()
            $dto.Name = $name
            $dto.Path = $this.Instances.GetFolder($name)
            $dto.Size = $this.Instances.GetVhdxSize($name)
            $rows += $dto
        }
        return @($rows)
    }

    [string[]] GetRunningNames() {
        return @($this.Wsl.GetRunningNames())
    }

    [GetBuildSourcesResponseDto] GetBuildSources() {
        $response = [GetBuildSourcesResponseDto]::new()
        $response.Dockerfiles = @($this.FormatSourceRows(@($this.Config.GetDockerfiles())))
        $response.Onboardings = @($this.FormatSourceRows(@($this.Config.GetOnboardings())))
        $response.Recipes = @($this.FormatSourceRows(@($this.Config.GetRecipes())))
        return $response
    }

    [WslBuildSourceDto] CreateRecipe([NewRecipeDto]$dto) {
        $target = $this.Config.CreateRecipe("$($dto.Name)".Trim())
        $row = [PSCustomObject]@{
            Name     = (Split-Path -Leaf $target)
            Path     = $target
            Modified = (Get-Item -LiteralPath $target).LastWriteTime
            Family   = ""
        }
        return @($this.FormatSourceRows(@($row)))[0]
    }

    [void] OpenInEditor([string]$path) {
        $code = Get-Command code -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($code) {
            Start-Process -FilePath $code.Path -ArgumentList "`"$path`""
            return
        }
        Start-Process -FilePath $path
    }

    [RegisterDockerResponseDto] RegisterDocker([RegisterDockerDto]$dto) {
        $name = "$($dto.InstanceName)"
        $response = [RegisterDockerResponseDto]::new()
        $response.InstanceName = $name
        try { $this.Docker.SetDesktopState($name) }
        catch { throw "Docker Desktop's settings could not take '$name': $($_.Exception.Message)" }
        if ($dto.Restart) {
            if ($this.Docker.TestRunning()) {
                $response.Restart = if ($this.Docker.RestartDesktop()) { "restarted" } else { "pending" }
            } else {
                $response.Restart = if ($this.Docker.StartDesktop()) { "started" } else { "pending" }
            }
        }
        return $response
    }

    [UnregisterDockerResponseDto] UnregisterDocker([UnregisterDockerDto]$dto) {
        $name = "$($dto.InstanceName)"
        $response = [UnregisterDockerResponseDto]::new()
        $response.InstanceName = $name
        try { $this.Docker.RemoveDesktopState($name) }
        catch { throw "Docker Desktop's settings could not release '$name': $($_.Exception.Message)" }
        if ($dto.Restart -and $this.Docker.TestRunning()) {
            $response.Restart = if ($this.Docker.RestartDesktop()) { "restarted" } else { "pending" }
        }
        return $response
    }

    hidden [WslBuildSourceDto[]] FormatSourceRows([object[]]$rows) {
        $out = @()
        foreach ($row in @($rows | Sort-Object Name)) {
            $dto = [WslBuildSourceDto]::new()
            $dto.Name = "$($row.Name -replace '-[0-9a-f]{8}$', '') ($($row.Modified.ToString("dd'/'MM HH:mm")))"
            $dto.Path = "$($row.Path)"
            $dto.Family = "$($row.Family)"
            $dto.Uploaded = ("$($row.Name)" -match '-[0-9a-f]{8}$')
            $out += $dto
        }
        return @($out)
    }

    [WslBuildSourceDto] UploadRecipe([UploadRecipeDto]$dto) {
        $target = $this.Config.CopyRecipe($dto.Kind, $dto.Source, $dto.FileName)
        $row = [PSCustomObject]@{
            Name     = (Split-Path -Path (Split-Path -Path $target -Parent) -Leaf)
            Path     = $target
            Modified = (Get-Item -LiteralPath $target).LastWriteTime
            Family   = if ($dto.FileName -eq "Dockerfile") { $this.Config.ReadRecipeFamily($target) } else { "" }
        }
        return @($this.FormatSourceRows(@($row)))[0]
    }

    [bool] TestDocker() {
        return $this.Docker.TestRunning()
    }

    [bool] StartDocker() {
        if ($this.Docker.TestRunning()) { return $true }
        return $this.Docker.StartDesktop()
    }

    [void] DeleteRecipe([string]$path) {
        $this.Config.RemoveRecipe($path)
    }

    [void] ExportRecipe([ExportRecipeDto]$dto) {
        $this.Config.ExportRecipe($dto.Path, $dto.Target)
    }

    [WslBuildPackDto[]] GetBuildPacks() {
        $rows = @()
        foreach ($pack in @($this.ReadCatalog().OfferedFor(""))) {
            $dto = [WslBuildPackDto]::new()
            $dto.Name = $pack.GetName()
            $dto.Family = $pack.GetFamily()
            $dto.Description = $pack.GetDescription()
            $dto.Shell = ($pack.GetName() -eq "oh_my_shell")
            $rows += $dto
        }
        return @($rows)
    }

    [BuildResponseDto] Build([BuildDto]$dto) {
        $name = $dto.Name
        $user = $dto.User

        foreach ($distro in @($this.Wsl.GetAllDistros())) {
            if ($distro.GetName() -eq $name) { throw "An instance named '$name' is registered on this machine." }
        }
        if ($this.Instances.IsFolderOccupied($name)) {
            throw "Installation folder '$($this.Instances.GetFolder($name))' already exists and is not empty."
        }

        $tag = "wsl-fleet:$name"
        $imageRef = $dto.BuildPath
        if ($dto.BuildType -in @([WslBuildType]::Dockerfile, [WslBuildType]::Recipe)) {
            if ($dto.BuildType -eq [WslBuildType]::Recipe -and -not (Test-Path -LiteralPath $dto.BuildPath -PathType Leaf)) {
                throw "The recipe carries no Dockerfile: '$($dto.Context)'."
            }
            $this.Docker.Build($tag, $dto.BuildPath, $dto.Context)
            $imageRef = $tag
        } elseif ($dto.BuildType -eq [WslBuildType]::Image) {
            $imageRef = $this.Docker.Load($dto.BuildPath)
        }

        $installPath = $this.Instances.GetFolder($name)
        $tarPath = Join-Path (Split-Path $installPath -Parent) "$name-rootfs.tar"
        try {
            $this.Docker.ExportRootfs($imageRef, $tarPath)
            if (-not (Test-Path $installPath)) { $null = New-Item -ItemType Directory -Path $installPath -Force }
            $this.Wsl.Import($name, $installPath, $tarPath)
        } catch {
            Remove-Item -Recurse -Force $installPath -ErrorAction SilentlyContinue
            throw
        } finally {
            Remove-Item $tarPath -Force -ErrorAction SilentlyContinue
        }

        $this.Instances.WriteMarker($name, "build")

        $instance = [WslInstance]::new()
        $instance.SetName($name)
        $instance.SetDefaultUser($user)
        $theme = [WslTheme]::Default($name)
        if ($dto.Font) { $theme.SetFont($dto.Font) }
        if ($dto.ColourScheme) { $theme.SetColourScheme($dto.ColourScheme) }
        if ($dto.Icon) { $theme.SetIcon($dto.Icon) }
        $instance.SetTheme($theme)

        if ($dto.Onboarding) {
            $this.Wsl.SaveOnboardingScript($name, $dto.Onboarding)
            $this.Wsl.RunOnboarding($name, $user)
            $this.Wsl.Terminate($name)
        } else {
            $imageUser = ""
            foreach ($line in @($this.Wsl.GetInInstance($name, @("cat", "/etc/wsl.conf")))) {
                if ("$line" -match '^\s*default\s*=\s*(\S+)\s*$') { $imageUser = $Matches[1]; break }
            }
            if (-not $imageUser) { $imageUser = "root" }
            $instance.SetDefaultUser($imageUser)
        }

        $warnings = @()
        try {
            $warnings += @($this.ApplyLook($name, $instance))
        } catch {
            $warnings += "the look failed: $($_.Exception.Message)"
        }

        if ($dto.BuildType -eq [WslBuildType]::Dockerfile) {
            if ($dto.KeepImage) {
                $savePath = $this.Docker.GetSavedImagePath($name)
                if (-not $this.Docker.SaveImage($tag, $savePath)) {
                    $warnings += "the image could not be saved to '$savePath'."
                }
            }
            $null = $this.Docker.RemoveImage($tag)
        }

        if ($dto.RegisterDocker) {
            $this.RegisterDockerDesktop($name)
            $warnings += @($this.WaitDockerClient($name))
        }

        if (@($dto.Packs).Count -gt 0) {
            try {
                $warnings += @($this.InstallChosenPacks($name, @($dto.Packs)))
            } catch {
                $warnings += "not installed - $($_.Exception.Message)"
            }
        }

        $response = [BuildResponseDto]::new()
        $response.InstanceName = $name
        $response.Status = if ($warnings.Count -gt 0) { [WslRecipeStatus]::Warning } else { [WslRecipeStatus]::Ok }
        $response.Messages = @($warnings)
        return $response
    }

    [OpenResponseDto] Open([string]$instanceName) {
        $response = [OpenResponseDto]::new()
        $response.InstanceName = $instanceName
        if ($this.Terminal.HasWslProfile($instanceName)) {
            $this.Terminal.TouchSettings()
            $this.Wsl.OpenProfile($instanceName)
            $response.Profile = $true
            return $response
        }
        $this.Wsl.OpenBareShell($instanceName)
        $response.Profile = $false
        return $response
    }

    [RestartResponseDto] Restart([string]$instanceName) {
        try {
            $this.Wsl.Terminate($instanceName)
        } catch {
            throw "The stop did not complete - '$instanceName' may still be running, and was not started again. $($_.Exception.Message)"
        }
        try {
            $this.Wsl.Start($instanceName)
        } catch {
            throw "The start did not complete - '$instanceName' is stopped. $($_.Exception.Message)"
        }
        $response = [RestartResponseDto]::new()
        $response.InstanceName = $instanceName
        return $response
    }

    [void] Remove([RemoveDto]$dto) {
        $name = $dto.InstanceName

        if ($dto.ArchiveFirst) {
            try {
                $null = $this.Archive($this.ArchiveDtoFor($name))
            } catch {
                throw "The archive did not complete - nothing was destroyed. $($_.Exception.Message)"
            }
        }

        $this.Wsl.TerminateQuietly($name)
        $this.Wsl.Unregister($name)
        $this.Instances.RemoveFolder($name)

        $fragments = $this.Terminal.GetWslGuids($name)
        $null = $this.Terminal.PruneGhostEntries($name, @($fragments.Guids))
        $this.Terminal.DeleteFragment($name)
        $null = $this.Terminal.RemoveStaleFragments(@($fragments.Guids))

        try {
            $this.Docker.RemoveDesktopState($name)
        } catch { }
    }

    [CompactResponseDto] Compact([CompactDto]$dto) {
        $name = $dto.InstanceName
        $archived = $false

        if ($dto.ArchiveFirst) {
            try {
                $null = $this.Archive($this.ArchiveDtoFor($name))
            } catch {
                throw "The archive did not complete - nothing was compacted: $($_.Exception.Message)"
            }
            $archived = $true
        }

        $wasRunning = @($this.Wsl.GetRunningNames()) -contains $name

        $sizeBefore = $this.Instances.GetVhdxSize($name)
        $this.Wsl.Compact($name)
        $sizeAfter = $this.Instances.GetVhdxSize($name)

        $restarted = $false
        if ($wasRunning) {
            try { $this.Wsl.Start($name); $restarted = $true } catch { }
        }

        $response = [CompactResponseDto]::new()
        $response.InstanceName = $name
        $response.Archived = $archived
        $response.Restarted = $restarted
        $response.SizeBefore = $sizeBefore
        $response.SizeAfter = $sizeAfter
        $response.Gained = $sizeBefore - $sizeAfter
        return $response
    }

    [string[]] GetFonts() {
        $names = @()
        foreach ($name in @($this.Config.GetPromptFontNames())) {
            if ($names -notcontains $name) { $names += $name }
        }
        foreach ($font in @($this.Terminal.GetTerminalFonts())) {
            if ($names -notcontains $font.Name) { $names += $font.Name }
        }
        return @($names)
    }

    [WslIconPairDto[]] GetIconPairs() {
        $rows = @()
        foreach ($pair in @($this.Terminal.GetIconPairs())) {
            $dto = [WslIconPairDto]::new()
            $dto.Name = "$($pair.Name)"
            $dto.Top = "$($pair.Top)"
            $dto.Bottom = "$($pair.Bottom)"
            $dto.TextColor = "$($pair.TextColor)"
            $rows += $dto
        }
        return @($rows)
    }

    [GetAppearanceResponseDto] GetAppearance([string]$instanceName) {
        $theme = $this.Terminal.GetAppearance($instanceName)

        $storedTheme = $this.Instances.GetInstance($instanceName).GetTheme()
        if ($null -ne $storedTheme) {
            $drawing = $storedTheme.GetIcon()
            if ($drawing.Text) { $theme.SetIcon($drawing) }
        }
        if ($this.Instances.HasIcon($instanceName)) {
            $theme.SetIconPath($this.Instances.GetIconPath($instanceName))
        }

        return $this.Map.ToAppearanceResponse($theme, $this.Terminal.HasFragment($instanceName))
    }
    [SetAppearanceResponseDto] SetAppearance([SetAppearanceDto]$dto) {
        $name = $dto.InstanceName
        $model = $this.Instances.GetInstance($name)

        $theme = $this.Terminal.GetAppearance($name)
        $storedTheme = $model.GetTheme()
        if ($null -ne $storedTheme) {
            $drawing = $storedTheme.GetIcon()
            if ($drawing.Text) { $theme.SetIcon($drawing) }
        }

        $changes = @()
        $rewriteProfile = $false

        if ($dto.Font) {
            $theme.SetFont($dto.Font)
            $changes += "font '$($dto.Font)'"
            $rewriteProfile = $true
        }
        if ($dto.ColourScheme) {
            $theme.SetColourScheme($dto.ColourScheme)
            $changes += "colours '$($dto.ColourScheme)'"
            $rewriteProfile = $true
        }
        if ($dto.Icon) {
            $iconPath = $this.Instances.GetIconPath($name)
            $theme.SetIcon($this.Terminal.DrawIcon($name, $iconPath, $dto.Icon))
            $theme.SetIconPath($iconPath)
            $changes += "icon"
            $rewriteProfile = $true
        }
        if ($dto.IconImage) {
            $this.Instances.SaveIcon($name, $dto.IconImage)
            $theme.SetIconPath($this.Instances.GetIconPath($name))
            $changes += "icon image"
        }

        if (-not $rewriteProfile) {
            $response = [SetAppearanceResponseDto]::new()
            $response.InstanceName = $name
            $response.Changes = @($changes)
            return $response
        }

        $guid = $this.Terminal.GetProfileGuid($name)
        if (-not $guid) {
            throw "Windows Terminal has no profile for '$name' - the look cannot be applied."
        }
        $this.Terminal.SaveFragment($name, $guid, $theme)
        $model.SetTheme($theme)
        $this.Instances.SaveInstance($model, "")
        $this.Terminal.TouchSettings()

        $response = [SetAppearanceResponseDto]::new()
        $response.InstanceName = $name
        $response.Changes = @($changes)
        return $response
    }

    [WslColorSchemeDto[]] GetColorSchemes() {
        $rows = @()
        foreach ($scheme in @($this.Terminal.GetColorSchemes())) {
            $dto = [WslColorSchemeDto]::new()
            foreach ($property in $scheme.PSObject.Properties) {
                $dto.$($property.Name) = $property.Value
            }
            $rows += $dto
        }
        return @($rows)
    }

    [GetPacksResponseDto] GetPacks([string]$instanceName) {
        $catalog = $this.ReadCatalog()
        $packsDirectory = $this.PacksDirectory($instanceName)
        $installed = @($this.Wsl.GetInstalledPacks($instanceName, $packsDirectory))
        $family = $this.Wsl.GetFamily($instanceName)

        $response = [GetPacksResponseDto]::new()
        $response.Installed = @($installed)

        $candidate = @()
        foreach ($pack in @($catalog.OfferedFor($family))) {
            if ($installed -contains $pack.GetName()) { continue }
            $candidate += $this.Map.ToPackDto($pack)
        }
        $response.Candidate = @($candidate)

        $removable = @()
        foreach ($packName in $installed) {
            $pack = $catalog.GetPack($packName)
            if ($null -ne $pack -and -not $pack.GetOffered()) { continue }
            $removable += $packName
        }
        $response.Removable = @($removable)

        return $response
    }

    [ManagePacksResponseDto] ManagePacks([ManagePacksDto]$dto) {
        $name = $dto.InstanceName
        $catalog = $this.ReadCatalog()
        $packsDirectory = $this.PacksDirectory($name)
        $errorLog = Join-Path $this.Instances.GetFolder($name) "pack-errors.log"
        Remove-Item -Path $errorLog -Force -ErrorAction SilentlyContinue

        $before = @($this.Wsl.GetInstalledPacks($name, $packsDirectory))

        $toRemove = @($catalog.ResolveRemoval($before, @($dto.ToRemove), @($dto.ToAdd)))
        $conflicts = @($catalog.GetRemovalConflicts($before, $toRemove, @($dto.ToAdd)))
        if ($conflicts.Count -gt 0) {
            throw ("'{0}' cannot be removed: required by {1}." -f $conflicts[0].Name, ($conflicts[0].Blockers -join " and "))
        }

        $response = [ManagePacksResponseDto]::new()
        $response.InstanceName = $name
        $response.ExitCode = 0
        $response.Installed = @()
        $response.Removed = @()
        $response.Failed = @()

        foreach ($packName in @($dto.ToAdd)) {
            $pack = $catalog.GetPack($packName)
            if ($null -eq $pack) { continue }
            $result = $this.InstallPack($name, $pack, $packsDirectory, $errorLog)
            if ($result.Step -in @("installed", "declined")) { continue }

            $response.Outcome = "failed"
            $response.ExitCode = $result.ExitCode
            $response.Failed = @($result.Pack)
            $after = @($this.Wsl.GetInstalledPacks($name, $packsDirectory))
            $response.Installed = @($this.DiffNames($after, $before))
            return $response
        }

        foreach ($packName in $toRemove) {
            $result = $this.RemoveOne($name, $packName, $packsDirectory, $errorLog)
            if ($null -eq $result) { continue }

            $response.Outcome = "failed"
            $response.ExitCode = $result.ExitCode
            $response.Failed = @($result.Pack)
            $after = @($this.Wsl.GetInstalledPacks($name, $packsDirectory))
            $response.Installed = @($this.DiffNames($after, $before))
            $response.Removed = @($this.DiffNames($before, $after))
            return $response
        }

        if ($toRemove.Count -gt 0) {
            $null = $this.Wsl.RunOrphanCleanup($name)
        }

        $after = @($this.Wsl.GetInstalledPacks($name, $packsDirectory))
        $response.Outcome = "ok"
        $response.Installed = @($this.DiffNames($after, $before))
        $response.Removed = @($this.DiffNames($before, $after))
        return $response
    }

    [WslDockerImageDto[]] GetAllSavedImages() {
        $rows = @()
        foreach ($image in @($this.Docker.GetAllSavedImages())) {
            $dto = [WslDockerImageDto]::new()
            $dto.Name = "$($image.Name) ($($image.Modified.ToString("dd'/'MM HH:mm")))"
            $dto.Path = "$($image.Path)"
            $dto.Uploaded = ((Split-Path -Path (Split-Path -Path "$($image.Path)" -Parent) -Leaf) -match '-[0-9a-f]{8}$')
            $rows += $dto
        }
        return @($rows)
    }

    [IsRegistryImageValidResponseDto] IsRegistryImageValid([string]$imageRef) {
        $answer = $this.Docker.TestRegistryImage($imageRef)
        $dto = [IsRegistryImageValidResponseDto]::new()
        $dto.Valid = [bool]$answer.Ok
        $dto.Why = "$($answer.Why)"
        return $dto
    }

    [ArchiveResponseDto] Archive([ArchiveDto]$dto) {
        $name = $dto.InstanceName
        $format = $dto.Format
        $archiveName = "$($name)_archive"
        $archiveDir = $this.Archives.GetFolder($archiveName)
        $archiveTar = Join-Path $archiveDir "$archiveName.$format"

        $diskBytes = $this.Instances.GetVhdxSize($name)
        $freeBytes = $this.Instances.GetFreeSpace($archiveDir)
        if ($freeBytes -lt $diskBytes) {
            $drive = (Split-Path -Qualifier ([System.IO.Path]::GetFullPath($archiveDir))).TrimEnd(':')
            throw ("Not enough room on {0}: needed {1}, free {2}." -f $drive, (Format-Size $diskBytes), (Format-Size $freeBytes))
        }

        $stopped = $false
        if (@($this.Wsl.GetRunningNames()) -contains $name) {
            if (-not $dto.Permit) {
                throw "'$name' is running, and stopping it was not allowed: an archive reads a still disk."
            }
            $this.Wsl.Terminate($name)
            $stopped = $true
        }

        $stored = $this.Instances.GetInstance($name)
        $theme = $stored.GetTheme()
        if ($null -eq $theme) { $theme = [WslTheme]::Default($name) }

        try {
            if ($this.Archives.HasArchive($archiveName)) {
                $this.Archives.DeleteArchive($archiveName)
            }
            $this.Archives.EnsureFolder($archiveName)

            try {
                $this.Wsl.Export($name, $archiveTar, $format)
            } catch {
                Remove-Item $archiveTar -Force -ErrorAction SilentlyContinue
                throw
            }

            if ($this.Instances.HasIcon($name)) {
                $this.Archives.SaveIcon($archiveName, $this.Instances.GetIconPath($name))
                $theme.SetIconPath($this.Archives.GetIconPath($archiveName))
            }

            $archive = [WslInstance]::new()
            $archive.SetName($archiveName)
            $archive.SetIsArchive($true)
            $archive.SetDefaultUser($stored.GetDefaultUser())
            $archive.SetTheme($theme)
            $this.Archives.SaveInstance($archive, $this.Docker.GetDesktopState($name))
        } finally {
            if ($stopped) { $this.Wsl.Start($name) }
        }

        $response = [ArchiveResponseDto]::new()
        $response.InstanceName = $name
        $response.ArchiveDir = $archiveDir
        $response.Tar = $archiveTar
        $response.LookFont = $theme.GetFontName()
        $response.LookColourScheme = $theme.GetColorScheme()
        $response.Docker = $this.Docker.GetDesktopState($name)
        $response.Stopped = $stopped
        return $response
    }

    [RestoreResponseDto] Restore([RestoreDto]$dto) {
        $archiveName = $dto.ArchiveName
        $name = $dto.InstanceName

        foreach ($distro in @($this.Wsl.GetAllDistros())) {
            if ($distro.GetName() -eq $name) { throw "An instance named '$name' already exists." }
        }
        $installPath = $this.Instances.GetFolder($name)
        if (Test-Path $installPath) {
            throw "A folder with that name already exists: $installPath"
        }

        $tar = $this.Archives.GetTar($archiveName)
        if (-not $tar) {
            throw "No tar in the archive folder: $($this.Archives.GetFolder($archiveName))"
        }

        $this.Wsl.Import($name, $installPath, $tar)
        $this.Instances.WriteMarker($name, "restore")

        $stored = $this.Archives.GetInstance($archiveName)
        $theme = $stored.GetTheme()
        if ($null -eq $theme) { $theme = [WslTheme]::Default($name) }
        if ($this.Archives.HasIcon($archiveName)) {
            $this.Instances.SaveIcon($name, $this.Archives.GetIconPath($archiveName))
            $theme.SetIconPath($this.Instances.GetIconPath($name))
        }

        $guid = $this.Terminal.GetProfileGuid($name)
        if ($guid) { $this.Terminal.SaveFragment($name, $guid, $theme) }

        $instance = [WslInstance]::new()
        $instance.SetName($name)
        $instance.SetDefaultUser($stored.GetDefaultUser())
        $instance.SetTheme($theme)
        $this.Instances.SaveInstance($instance, "")
        $this.Terminal.TouchSettings()

        $carried = $this.Archives.GetDocker($archiveName)
        if ($carried -eq "yes" -and $this.Docker.GetDesktopState($name) -eq "no") {
            $this.Docker.SetDesktopState($name)
            $null = $this.Docker.RestartDesktop()
        }

        $response = [RestoreResponseDto]::new()
        $response.ArchiveName = $archiveName
        $response.InstanceName = $name
        return $response
    }

    [DeleteArchiveResponseDto] DeleteArchive([string]$archive) {
        $this.Archives.DeleteArchive($archive)
        $response = [DeleteArchiveResponseDto]::new()
        $response.ArchiveName = $archive
        return $response
    }

    [DuplicateResponseDto] Duplicate([DuplicateDto]$dto) {
        $source = $dto.SourceName
        $copy = $dto.CopyName

        foreach ($distro in @($this.Wsl.GetAllDistros())) {
            if ($distro.GetName() -eq $copy) { throw "An instance named '$copy' already exists." }
        }
        foreach ($archive in @($this.Archives.GetAllArchives())) {
            if ($archive.GetName() -eq $copy) { throw "An instance named '$copy' already exists." }
        }

        $destination = $this.Instances.GetFolder($copy)
        $diskBytes = $this.Instances.GetVhdxSize($source)
        $needed = 2 * $diskBytes
        $freeBytes = $this.Instances.GetFreeSpace($destination)
        if ($freeBytes -lt $needed) {
            $drive = (Split-Path -Qualifier ([System.IO.Path]::GetFullPath($destination))).TrimEnd(':')
            throw ("Not enough room on {0}: needed {1}, free {2}." -f $drive, (Format-Size $needed), (Format-Size $freeBytes))
        }

        $stored = $this.Instances.GetInstance($source)
        $theme = $this.Terminal.GetAppearance($source)
        $storedTheme = $stored.GetTheme()
        if ($null -ne $storedTheme) {
            $drawing = $storedTheme.GetIcon()
            if ($drawing.Text) { $theme.SetIcon($drawing) }
        }
        $dockerCarried = $this.Docker.GetDesktopState($source)

        $stopped = $false
        if (@($this.Wsl.GetRunningNames()) -contains $source) {
            $this.Wsl.Terminate($source)
            $stopped = $true
        }

        $tempTar = Join-Path (Split-Path $destination -Parent) "$copy-export.tar.gz"
        try {
            $this.Wsl.Export($source, $tempTar, "tar.gz")
            $this.Wsl.Import($copy, $destination, $tempTar)

            $this.Instances.WriteMarker($copy, "duplicate")

            if ($this.Instances.HasIcon($source)) {
                $this.Instances.SaveIcon($copy, $this.Instances.GetIconPath($source))
                $theme.SetIconPath($this.Instances.GetIconPath($copy))
            }
            $guid = $this.Terminal.GetProfileGuid($copy)
            if ($guid) { $this.Terminal.SaveFragment($copy, $guid, $theme) }

            $instance = [WslInstance]::new()
            $instance.SetName($copy)
            $instance.SetDefaultUser($stored.GetDefaultUser())
            $instance.SetTheme($theme)
            $this.Instances.SaveInstance($instance, "")
            $this.Terminal.TouchSettings()

            if ($dockerCarried -eq "yes" -and $this.Docker.GetDesktopState($copy) -eq "no") {
                $this.Docker.SetDesktopState($copy)
                $null = $this.Docker.RestartDesktop()
            }
        } finally {
            if (Test-Path $tempTar) { Remove-Item $tempTar -Force -ErrorAction SilentlyContinue }
            if ($stopped) { $this.Wsl.Start($source) }
        }

        $response = [DuplicateResponseDto]::new()
        $response.SourceName = $source
        $response.CopyName = $copy
        return $response
    }

    hidden [ArchiveDto] ArchiveDtoFor([string]$name) {
        $dto = [ArchiveDto]::new()
        $dto.InstanceName = $name
        $dto.Format = "tar.gz"
        $dto.Permit = $true
        return $dto
    }

    hidden [string[]] ApplyLook([string]$name, [WslInstance]$instance) {
        $warnings = @()
        $theme = $instance.GetTheme()

        if (-not $this.Terminal.IsFontInstalled($theme.GetFontName())) {
            try { $this.Terminal.InstallFont($theme.GetFontName(), "") }
            catch { $warnings += "the font '$($theme.GetFontName())' would not install: $($_.Exception.Message)" }
        }

        $iconPath = $this.Instances.GetIconPath($name)
        $iconDrawn = $false
        try {
            $theme.SetIcon($this.Terminal.DrawIcon($name, $iconPath, $null))
            $iconDrawn = $true
        } catch {
            Remove-Item $iconPath -Force -ErrorAction SilentlyContinue
            $warnings += "no icon ($($_.Exception.Message))"
        }

        $fragments = $this.Terminal.GetWslGuids($name)
        if (@($fragments.Guids).Count -gt 0) {
            $ghosts = $this.Terminal.PruneGhostEntries($name, @($fragments.Guids))
            foreach ($path in @($ghosts.Unreadable)) {
                $warnings += "ghost entries NOT pruned in $path (unreadable JSON - a // comment breaks ConvertFrom-Json; remove them by hand)"
            }
        }
        $null = $this.Terminal.RemoveStaleFragments(@($fragments.Guids))

        if ($fragments.Guid) {
            $theme.SetIconPath($(if ($iconDrawn) { $iconPath } else { "" }))
            $this.Terminal.SaveFragment($name, $fragments.Guid, $theme)
        } else {
            $warnings += "no WSL fragment for '$name' - the profile was not applied"
        }

        $instance.SetTheme($theme)
        $this.Instances.SaveInstance($instance, "")
        $this.Terminal.TouchSettings()

        return @($warnings)
    }

    hidden [void] RegisterDockerDesktop([string]$name) {
        try { $this.Docker.SetDesktopState($name) }
        catch { throw "Docker Desktop's settings could not take '$name': $($_.Exception.Message)" }
        if (-not $this.Docker.RestartDesktop()) {
            throw "Docker Desktop would not restart to pick '$name' up."
        }
    }

    hidden [string[]] WaitDockerClient([string]$name) {
        $usable = $false
        for ($attempt = 1; $attempt -le 5 -and -not $usable; $attempt++) {
            $usable = $this.Wsl.TestInInstance($name, @("docker", "version"))
            if (-not $usable) { Start-Sleep -Seconds 2 }
        }
        if ($usable) {
            return @("Docker Desktop: ready - 'docker' works in this instance.")
        }
        return @(
            "Docker Desktop: 'docker' does not answer in this instance yet.",
            "run 'docker version' in there; if it names the socket's permissions, restart Docker Desktop and open a new terminal."
        )
    }

    hidden [string[]] InstallChosenPacks([string]$name, [string[]]$chosen) {
        $catalog = $this.ReadCatalog()
        $packsDirectory = $this.PacksDirectory($name)
        $errorLog = Join-Path $this.Instances.GetFolder($name) "pack-errors.log"

        foreach ($packName in @($catalog.ResolveSelection($chosen, @()))) {
            $pack = $catalog.GetPack($packName)
            if ($null -eq $pack) { continue }

            $result = $this.InstallPack($name, $pack, $packsDirectory, $errorLog)
            if ($result.Step -in @("installed", "declined")) { continue }

            $notes = @("'$($result.Pack)' installation failed.")
            $now = @($this.Wsl.GetInstalledPacks($name, $packsDirectory))
            $skipped = @()
            foreach ($wanted in $chosen) {
                if ($wanted -ne $result.Pack -and $now -notcontains $wanted) { $skipped += $wanted }
            }
            if ($skipped.Count -gt 0) { $notes += "$($skipped -join ', ') installation skipped." }
            return $notes
        }
        return @()
    }

    hidden [WslPackCatalog] ReadCatalog() {
        $catalog = [WslPackCatalog]::new()
        $catalog.SetPacks(@($this.Packs.GetAllPacks()))
        return $catalog
    }

    hidden [string] PacksDirectory([string]$name) {
        $home = $this.Wsl.GetHome($name)
        if (-not $home) { throw "'$name' did not say where its user's home is." }
        return "$home/.config/packs"
    }

    hidden [object] InstallPack([string]$name, [WslPack]$pack, [string]$packsDirectory, [string]$errorLog) {
        $target = "$packsDirectory/$($pack.GetName())"

        $code = $this.Wsl.CopyFolderIntoInstance($name, $this.Packs.GetFolder($pack.GetName()), $target)
        if ($code -ne 0) {
            $null = $this.Wsl.RemoveFolderInInstance($name, $target)
            return [PSCustomObject]@{ Pack = $pack.GetName(); Step = "copy"; ExitCode = $code }
        }

        if ($this.Wsl.HasInInstance($name, "$target/install_root.sh")) {
            $rootCode = $this.Wsl.RunScriptInInstance($name, $target, "install_root.sh", $true, $errorLog)
            if ($rootCode -ne 0) {
                $null = $this.Wsl.RemoveFolderInInstance($name, $target)
                return [PSCustomObject]@{ Pack = $pack.GetName(); Step = "root"; ExitCode = $rootCode }
            }
        }

        $sudoWindow = $false
        try {
            $sudoWindow = $this.Wsl.OpenPackSudoWindow($name)
            $code = $this.Wsl.RunScriptInInstance($name, $target, "install.sh", $false, $errorLog)
        } finally {
            if ($sudoWindow) { $this.Wsl.ClosePackSudoWindow($name) }
        }

        if ($code -eq 2) {
            $null = $this.Wsl.RemoveFolderInInstance($name, $target)
            return [PSCustomObject]@{ Pack = $pack.GetName(); Step = "declined"; ExitCode = 0 }
        }
        if ($code -ne 0) {
            $null = $this.Wsl.RemoveFolderInInstance($name, $target)
            return [PSCustomObject]@{ Pack = $pack.GetName(); Step = "install"; ExitCode = $code }
        }

        return [PSCustomObject]@{ Pack = $pack.GetName(); Step = "installed"; ExitCode = 0 }
    }

    hidden [object] RemoveOne([string]$name, [string]$packName, [string]$packsDirectory, [string]$errorLog) {
        $target = "$packsDirectory/$packName"

        $catalogRemove = Join-Path $this.Packs.GetFolder($packName) "remove.sh"
        if (Test-Path $catalogRemove) {
            $null = $this.Wsl.CopyFileIntoInstance($name, $catalogRemove, "$target/remove.sh")
        }

        if ($this.Wsl.HasInInstance($name, "$target/remove.sh")) {
            $code = $this.Wsl.RunScriptInInstance($name, $target, "remove.sh", $true, $errorLog)
            if ($code -ne 0) {
                return [PSCustomObject]@{ Pack = $packName; Step = "remove"; ExitCode = $code }
            }
        }

        $code = $this.Wsl.RemoveFolderInInstance($name, $target)
        if ($code -ne 0) {
            return [PSCustomObject]@{ Pack = $packName; Step = "folder"; ExitCode = $code }
        }
        return $null
    }

    hidden [string[]] DiffNames([string[]]$after, [string[]]$before) {
        $diff = @()
        foreach ($name in $after) {
            if ($before -notcontains $name) { $diff += $name }
        }
        return @($diff)
    }
}
