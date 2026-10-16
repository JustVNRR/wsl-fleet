using module ..\Repositories\ConfigRepository.psm1
using module ..\Repositories\WslRepository.psm1
using module ..\Repositories\InstanceRepository.psm1
using module ..\Repositories\ArchiveRepository.psm1
using module .\InstanceService.psm1
using module ..\Dtos\InstanceDto.psm1
using module ..\Tools\Helpers.psm1

class FleetService {
    hidden [ConfigRepository]$Config
    hidden [WslRepository]$Wsl
    hidden [InstanceRepository]$Instances
    hidden [ArchiveRepository]$Archives
    hidden [InstanceService]$InstanceService

    FleetService([ConfigRepository]$config, [WslRepository]$wsl,
                 [InstanceRepository]$instances, [ArchiveRepository]$archives,
                 [InstanceService]$instanceService) {
        $this.Config = $config
        $this.Wsl = $wsl
        $this.Instances = $instances
        $this.Archives = $archives
        $this.InstanceService = $instanceService
    }

    [string] GetRoot() {
        $saved = $this.Config.GetSavedRoot()
        if ($saved -and (Test-Path $saved)) { return $saved }

        $homes = @($this.RootHomes())

        if (-not $saved) {
            $decided = ""
            if ($homes.Count -eq 1) { $decided = $homes[0] }
            elseif (Test-Path "D:\") { $decided = "D:\WSL" }
            else { $decided = "$env:USERPROFILE\WSL" }
            $this.Config.SaveRoot($decided)
            return $decided
        }

        if ($homes.Count -eq 1) {
            $this.Config.SaveRoot($homes[0])
            return $homes[0]
        }

        throw "The working folder '$saved' is gone, and no existing folder holds your instances."
    }

    [string] SetRoot([string]$target) {
        $problem = Test-FleetTarget $target
        if ($problem) { throw $problem }
        $this.Instances.EnsureFolder($target)
        $this.Archives.MoveTo($target)
        $this.Config.SaveRoot($target)
        return $target
    }

    [void] ReRoot([string]$root) {
        $this.Instances.ReRoot($root)
        $this.Archives.ReRoot($root)
        $this.InstanceService.ReRoot($root)
    }

    [string[]] GetFleet() {
        $root = $this.GetRoot()
        $names = @()
        foreach ($distro in @($this.Wsl.GetAllDistros())) {
            $folder = $this.Wsl.GetFolder($distro.GetName())
            if (-not $folder -or -not (Test-Path $folder)) { continue }
            if (-not $this.Instances.HasMarkerIn($folder)) { continue }
            if ((Split-Path -Path $folder -Parent).TrimEnd('\') -ne $root.TrimEnd('\')) { continue }
            $names += $distro.GetName()
        }
        return @($names | Sort-Object)
    }

    [WslConfigResponseDto] WslConfig() {
        $path = Join-Path $env:USERPROFILE ".wslconfig"
        $created = -not (Test-Path $path)
        $path = $this.Config.EnsureWslConfig()
        Start-Process -FilePath $path
        $response = [WslConfigResponseDto]::new()
        $response.Path = $path
        $response.Created = $created
        return $response
    }

    [MigrateResponseDto] Migrate([string]$target) {
        $problem = Test-FleetTarget $target
        if ($problem) { throw $problem }
        $response = [MigrateResponseDto]::new()
        $moved = @()
        foreach ($name in @($this.GetFleet())) {
            $dto = [RemoveDto]::new()
            $dto.InstanceName = $name
            $dto.ArchiveFirst = $true
            $this.InstanceService.Remove($dto)
            $moved += $name
        }
        $response.Moved = @($moved)
        $response.Target = $this.SetRoot($target)
        return $response
    }

    hidden [string[]] RootHomes() {
        $homes = @()
        foreach ($distro in @($this.Wsl.GetAllDistros())) {
            $folder = $this.Wsl.GetFolder($distro.GetName())
            if (-not $folder -or -not (Test-Path $folder)) { continue }
            if (-not $this.Instances.HasMarkerIn($folder)) { continue }
            $parent = Split-Path -Path $folder -Parent
            if ($homes -notcontains $parent) { $homes += $parent }
        }
        return @($homes)
    }
}
