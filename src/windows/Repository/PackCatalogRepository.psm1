# ==============================================================================
# LE DÉPÔT DU CATALOGUE DES PACKS
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout un type qu'il a tiré
# lui-même.
using module ..\Model\WslPack.psm1

# Le dossier des packs, sur le disque : les dossiers qui portent un pack.conf,
# lus en déclarations ; la conf réécrite ; les copies et les suppressions de
# dossiers. Aucune règle ici : lire et écrire, rien de plus. La racine se tient
# à la construction ; le dossier d'un pack se résout par son nom.
class PackCatalogRepository {
    hidden [string]$PacksRoot

    PackCatalogRepository([string]$packsRoot) {
        $this.PacksRoot = $packsRoot
    }

    [string] GetFolder([string]$packName) {
        return (Join-Path $this.PacksRoot $packName)
    }

    # Le catalogue : chaque dossier qui porte un pack.conf, trié par nom — les
    # menus numérotent ces listes, l'ordre ne doit pas bouger. Un dossier sans
    # conf n'est pas un pack.
    [WslPack[]] GetAllPacks() {
        $packs = @()
        if (-not (Test-Path $this.PacksRoot)) { return @() }
        foreach ($dir in (Get-ChildItem -Path $this.PacksRoot -Directory | Sort-Object Name)) {
            if (-not (Test-Path (Join-Path $dir.FullName "pack.conf"))) { continue }
            $packs += $this.GetPack($dir.FullName)
        }
        return @($packs)
    }

    # Un pack.conf lu — les clés que le fichier porte, et rien de deviné. La
    # conf se lit par le builder : un champ vide ne pose rien.
    hidden [WslPack] GetPack([string]$folder) {
        $pack = [WslPack]::new().WithName((Split-Path -Path $folder -Leaf))
        foreach ($line in @(Get-Content -LiteralPath (Join-Path $folder "pack.conf") -Encoding UTF8)) {
            if ($line -match '^\s*PACK_DESCRIPTION\s*:=\s*(.+?)\s*$') { $null = $pack.WithDescription($Matches[1]) }
            elseif ($line -match '^\s*PACK_REQUIRES\s*:=\s*(.*)$') { $null = $pack.WithRequires(@($Matches[1] -split '\s+' | Where-Object { $_ })) }
            elseif ($line -match '^\s*PACK_VISIBLE\s*:=\s*(\S+)') { $null = $pack.WithOffered($Matches[1] -notmatch '^(?i)no$') }
            elseif ($line -match '^\s*PACK_FAMILY\s*:=\s*(\S+)') { $null = $pack.WithFamily($Matches[1].ToLower()) }
            elseif ($line -match '^\s*PACK_WELCOME\s*:=\s*(.+?)\s*$') { $null = $pack.WithWelcome($Matches[1]) }
        }
        return $pack
    }

    # La ligne du pack réécrite dans sa conf — ou ajoutée quand la conf ne la
    # porte pas encore. Rien d'autre ne nomme un pack : c'est toute la
    # réécriture d'un renommage.
    [void] SavePackDescription([string]$packName, [string]$description) {
        $confFile = Join-Path $this.GetFolder($packName) "pack.conf"
        $rewritten = @()
        $found = $false
        foreach ($line in @(Get-Content -LiteralPath $confFile -Encoding UTF8)) {
            if ($line -match '^\s*PACK_DESCRIPTION\s*:=') {
                $found = $true
                $rewritten += "PACK_DESCRIPTION := $description"
            } else {
                $rewritten += $line
            }
        }
        if (-not $found) { $rewritten += "PACK_DESCRIPTION := $description" }
        Set-Content -LiteralPath $confFile -Value $rewritten -Encoding utf8NoBOM
    }

    # Le pack neuf : le dossier de la source copié entier sous le nom neuf —
    # ses requirements et sa famille voyagent avec, rien d'autre ne nomme un
    # pack. Un nom déjà pris refuse.
    [void] CopyPack([string]$sourceName, [string]$newName) {
        if (Test-Path $this.GetFolder($newName)) {
            throw "A pack named '$newName' already lives in the catalogue."
        }
        Copy-Item -LiteralPath $this.GetFolder($sourceName) -Destination $this.GetFolder($newName) -Recurse -ErrorAction Stop
    }

    # Le pack ôté du catalogue : son dossier, entier. Une instance qui le
    # portait garde sa copie — ce que le dossier tenait était à elle depuis
    # l'installation.
    [void] DeletePack([string]$packName) {
        Remove-Item -LiteralPath $this.GetFolder($packName) -Recurse -Force -ErrorAction Stop
    }

    # Le dossier du pack, ouvert comme Windows ouvre les dossiers.
    [void] OpenFolder([string]$packName) {
        Start-Process -FilePath $this.GetFolder($packName)
    }
}
