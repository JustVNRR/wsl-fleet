using module ..\Entities\WslPackCatalog.psm1
using module ..\Repositories\InstanceRepository.psm1
using module ..\Repositories\ArchiveRepository.psm1
using module ..\Repositories\WslRepository.psm1
using module ..\Repositories\TerminalRepository.psm1
using module ..\Repositories\DockerRepository.psm1
using module ..\Repositories\PackCatalogRepository.psm1
using module ..\Repositories\ConfigRepository.psm1
using module .\InstanceService.psm1
using module .\FleetService.psm1
using module .\WpfService.psm1
using module .\PackCatalogService.psm1
using module .\LoggerService.psm1

class ServiceFactory {

    static [InstanceService] CreateInstanceService([string]$root, [string]$assets, [string]$distroTree) {
        return [InstanceService]::new(
            [InstanceRepository]::new($root),
            [ArchiveRepository]::new((Join-Path $root "archives")),
            [WslRepository]::new($distroTree),
            [TerminalRepository]::new($assets),
            [DockerRepository]::new($assets),
            [PackCatalogRepository]::new((Join-Path $assets "packs")),
            [ConfigRepository]::new($assets, $distroTree)
        )
    }

    static [LoggerService] CreateLoggerService() {
        $base = "$env:LOCALAPPDATA"
        if (-not $base) { $base = [IO.Path]::GetTempPath() }
        return [LoggerService]::new((Join-Path $base "wsl-fleet\wsl-fleet.log"))
    }

    static [string] ResolveRoot([string]$assets, [string]$distroTree) {
        $fleet = [ServiceFactory]::CreateFleetService([IO.Path]::GetTempPath(), $assets, $distroTree)
        return $fleet.GetRoot()
    }

    static [FleetService] CreateFleetService([string]$root, [string]$assets, [string]$distroTree) {
        $instances = [InstanceRepository]::new($root)
        $archives = [ArchiveRepository]::new((Join-Path $root "archives"))
        $wsl = [WslRepository]::new($distroTree)
        $config = [ConfigRepository]::new($assets, $distroTree)
        $service = [InstanceService]::new(
            $instances, $archives, $wsl,
            [TerminalRepository]::new($assets),
            [DockerRepository]::new($assets),
            [PackCatalogRepository]::new((Join-Path $assets "packs")),
            $config)
        return [FleetService]::new($config, $wsl, $instances, $archives, $service)
    }

    static [WpfService] CreateWpfService([string]$assets) {
        return [WpfService]::new([ConfigRepository]::new($assets), [TerminalRepository]::new($assets))
    }

    static [PackCatalogService] CreatePackCatalogService([string]$assets) {
        return [PackCatalogService]::new([WslPackCatalog]::new(), [PackCatalogRepository]::new((Join-Path $assets "packs")))
    }
}