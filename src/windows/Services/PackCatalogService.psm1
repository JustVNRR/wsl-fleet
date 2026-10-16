using module ..\Entities\WslPack.psm1
using module ..\Entities\WslPackCatalog.psm1
using module ..\Dtos\PackCatalogDto.psm1
using module ..\Repositories\PackCatalogRepository.psm1
using module ..\Mappers\InstanceMapper.psm1

class PackCatalogService {

    hidden [WslPackCatalog]$Catalog
    hidden [PackCatalogRepository]$Packs
    hidden [InstanceMapper]$Map

    PackCatalogService([WslPackCatalog]$catalog, [PackCatalogRepository]$packs) {
        $this.Catalog = $catalog
        $this.Packs = $packs
        $this.Map = [InstanceMapper]::new()
    }

    [WslPackDto[]] GetAllPacks() {
        $this.RefreshCatalog()
        $rows = @()
        foreach ($pack in @($this.Catalog.GetPacks())) {
            $dto = $this.Map.ToPackDto($pack)
            $dto.Dependents = @($this.Catalog.DependentsOf("$($pack.GetName())"))
            $rows += $dto
        }
        return @($rows)
    }

    [WslPackDto] GetPack([string]$packName) {
        $this.RefreshCatalog()
        $pack = $this.Catalog.GetPack($packName)
        if ($null -eq $pack) { return $null }
        return $this.Map.ToPackDto($pack)
    }

    [string] CreatePack([CreatePackDto]$dto) {
        $probe = [WslPack]::new()
        $probe.SetName($dto.NewName)

        $this.Packs.CopyPack($dto.SourceName, $dto.NewName)
        if ($dto.Description) {
            $this.Packs.SavePackDescription($dto.NewName, $dto.Description)
        }
        return $dto.NewName
    }

    [void] SetPackDescription([SetPackDescriptionDto]$dto) {
        $this.RequirePack($dto.PackName)
        $this.Packs.SavePackDescription($dto.PackName, $dto.Description)
    }

    [void] DeletePack([string]$packName) {
        $this.RequirePack($packName)
        $this.Packs.DeletePack($packName)
    }

    [void] OpenPackFolder([string]$packName) {
        $this.RequirePack($packName)
        $this.Packs.OpenFolder($packName)
    }

    hidden [void] RefreshCatalog() {
        $this.Catalog.SetPacks(@($this.Packs.GetAllPacks()))
    }

    hidden [void] RequirePack([string]$packName) {
        $this.RefreshCatalog()
        if ($null -eq $this.Catalog.GetPack($packName)) {
            throw "There is no pack named '$packName' in the catalogue."
        }
    }
}
