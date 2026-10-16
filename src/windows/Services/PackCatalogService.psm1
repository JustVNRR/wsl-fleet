# ==============================================================================
# LE CATALOGUE DES PACKS — LE SERVICE
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout un type qu'il a tiré
# lui-même.
using module ..\Entities\WslPack.psm1
using module ..\Entities\WslPackCatalog.psm1
using module ..\Dtos\PackCatalogDto.psm1
using module ..\Repositories\PackCatalogRepository.psm1
using module ..\Mappers\InstanceMapper.psm1

# Le CRUD du catalogue — chaque nom dit son objet : lister les packs, en lire
# un, en créer un (la copie d'une source), réécrire sa ligne, le supprimer,
# ouvrir son dossier. La règle des Dto comme partout — XxxDto en entrée quand
# il y a à demander, XxxResponseDto en retour quand il y a à rendre ; un seul
# champ se passe nu. Le catalogue du modèle reçoit ses déclarations du dépôt,
# relues à chaque demande — un pack posé sur le disque se voit tout de suite.
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
            $rows += $this.Map.ToPackDto($pack)
        }
        return @($rows)
    }

    [WslPackDto] GetPack([string]$packName) {
        $this.RefreshCatalog()
        $pack = $this.Catalog.GetPack($packName)
        if ($null -eq $pack) { return $null }
        return $this.Map.ToPackDto($pack)
    }

    # La création : un pack neuf copié d'une source — son dossier copié, sa
    # conf réécrite quand une description est donnée. La règle du nom vit sur
    # la classe : un nom refusé jette ici, avant qu'un dossier ne naisse.
    [string] CreatePack([CreatePackDto]$dto) {
        $probe = [WslPack]::new()
        $probe.SetName($dto.NewName)

        $this.Packs.CopyPack($dto.SourceName, $dto.NewName)
        if ($dto.Description) {
            $this.Packs.SavePackDescription($dto.NewName, $dto.Description)
        }
        return $dto.NewName
    }

    # La ligne du pack réécrite dans sa conf.
    [void] SetPackDescription([SetPackDescriptionDto]$dto) {
        $this.RequirePack($dto.PackName)
        $this.Packs.SavePackDescription($dto.PackName, $dto.Description)
    }

    # Le pack ôté du catalogue — son dossier, entier.
    [void] DeletePack([string]$packName) {
        $this.RequirePack($packName)
        $this.Packs.DeletePack($packName)
    }

    # Le dossier du pack ouvert.
    [void] OpenPackFolder([string]$packName) {
        $this.RequirePack($packName)
        $this.Packs.OpenFolder($packName)
    }

    # --- les pas partagés -------------------------------------------------------

    # Le catalogue relu du disque — les dossiers à pack.conf, en déclarations.
    hidden [void] RefreshCatalog() {
        $this.Catalog.SetPacks(@($this.Packs.GetAllPacks()))
    }

    # Un pack que le catalogue ne porte pas : refusé ici, d'une phrase — le
    # dossier, lui, jetterait la sienne, plus loin et plus vague.
    hidden [void] RequirePack([string]$packName) {
        $this.RefreshCatalog()
        if ($null -eq $this.Catalog.GetPack($packName)) {
            throw "There is no pack named '$packName' in the catalogue."
        }
    }
}
