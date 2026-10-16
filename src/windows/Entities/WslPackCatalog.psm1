# ==============================================================================
# LE CATALOGUE DES PACKS
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout un type qu'il a tiré
# lui-même.
using module .\WslPack.psm1

# Les déclarations que ce checkout porte, et leurs règles : qui s'offre à
# quelle famille, ce qu'une sélection installe (et dans quel ordre), ce qu'un
# retrait emporte, et ce qu'un retrait casserait. Le parcours des dossiers —
# lire, copier, supprimer — vit au PackRepo ; ici, les règles. Les champs
# sont hidden, la porte est la méthode (GetPacks/SetPacks).
class WslPackCatalog {
    hidden [WslPack[]]$Packs = @()

    WslPackCatalog() {}

    [WslPack[]] GetPacks() { return $this.Packs }
    # Les nuls sont ôtés en passant : un catalogue vide reste un tableau vide,
    # jamais un $null — mesuré : un `if` en valeur déroule @() en rien, et le
    # $null qu'il posait faisait jeter la première question posée au
    # catalogue (`@($null)` fait UNE ligne nulle).
    [void] SetPacks([WslPack[]]$packs) {
        $this.Packs = @($packs | Where-Object { $null -ne $_ })
    }

    # Un pack par son nom — rien quand le checkout ne le porte pas.
    [WslPack] GetPack([string]$name) {
        return @($this.Packs | Where-Object { $_.GetName() -eq $name })[0]
    }

    # Les packs qu'une question peut montrer sur une machine de cette
    # famille : les offerts dont la famille colle. Une famille vide ne filtre
    # rien — une machine qui n'a pas su dire ce qu'elle est reçoit la liste
    # entière, pas une moitié fausse.
    [WslPack[]] OfferedFor([string]$family) {
        if (-not $family) { return @($this.Packs | Where-Object { $_.GetOffered() }) }
        return @($this.Packs | Where-Object { $_.GetOffered() -and $_.GetFamily() -eq $family })
    }

    # La liste à installer, dans l'ordre : un pack s'installe par-dessus ce
    # qu'il requiert, donc les requirements d'abord — et un déjà installé
    # n'est pas placé deux fois. Un requirement que ce checkout ne porte pas
    # est sauté ici ; le pack qui l'a demandé est celui qui échouera.
    [string[]] ResolveSelection([string[]]$names, [string[]]$installed) {
        $seen = @{}
        $ordered = New-Object System.Collections.ArrayList
        foreach ($name in @($names)) {
            $this.AddRequires($name, $installed, $seen, $ordered)
        }
        return @($ordered)
    }

    # Le pas derrière ResolveSelection — privé (hidden) : un requirement deux
    # niveaux plus bas voyage avant les deux.
    hidden [void] AddRequires([string]$name, [string[]]$installed, [hashtable]$seen, [System.Collections.ArrayList]$ordered) {
        if ($seen.ContainsKey($name)) { return }
        $seen[$name] = $true

        $pack = $this.GetPack($name)
        if ($null -eq $pack) { return }

        # À travers lui même quand il est déjà là : ce qu'il requiert peut
        # manquer.
        foreach ($need in @($pack.GetRequires())) {
            $this.AddRequires($need, $installed, $seen, $ordered)
        }

        if ($installed -notcontains $name) { [void]$ordered.Add($name) }
    }

    # Ce qui part, avec ce qui doit partir avec : un pack invisible n'est
    # jamais dans la checklist — il part quand le dernier qui le requiert
    # part. Répété tant que quelque chose bouge : un invisible peut lui-même
    # en requérir un autre, et le second perd son dernier claimant au moment
    # où le premier part. $arriving porte les packs en route vers l'entrée :
    # l'un d'eux est un claimant aussi.
    [string[]] ResolveRemoval([string[]]$installed, [string[]]$leaving, [string[]]$arriving) {
        $gone = New-Object System.Collections.ArrayList
        foreach ($name in @($leaving)) { [void]$gone.Add($name) }

        do {
            $added = 0
            $remaining = @($installed | Where-Object { $gone -notcontains $_ }) + @($arriving)

            foreach ($name in @($installed)) {
                if ($gone -contains $name) { continue }

                # Pas porté par ce checkout : pas dans la checklist non plus,
                # et laissé tranquille pour la même raison. Un offert ne part
                # que parce que l'utilisateur l'a décoché.
                $pack = $this.GetPack($name)
                if ($null -eq $pack) { continue }
                if ($pack.GetOffered()) { continue }

                $claimed = $false
                foreach ($other in $remaining) {
                    $otherPack = $this.GetPack($other)
                    if ($null -ne $otherPack -and @($otherPack.GetRequires()) -contains $name) { $claimed = $true; break }
                }
                if (-not $claimed) {
                    [void]$gone.Add($name)
                    $added++
                }
            }
        } while ($added -gt 0)

        return @($gone)
    }

    # Les packs qui seraient encore debout et requerraient $name : ce qu'un
    # retrait de $name casserait. Un claimant qui part avec lui n'est pas un
    # claimant — les deux s'en vont ensemble. Un qui arrive le tient, lui : il
    # atterrit sur ce qui doit rester. Seules comptent les déclarations que ce
    # checkout porte.
    [string[]] GetBlockers([string]$name, [string[]]$installed, [string[]]$leaving, [string[]]$arriving) {
        $standing = @(@($installed) + @($arriving) | Where-Object { $leaving -notcontains $_ -and $_ -ne $name })
        $blockers = @()
        foreach ($other in $standing) {
            $pack = $this.GetPack($other)
            if ($null -ne $pack -and @($pack.GetRequires()) -contains $name) { $blockers += $other }
        }
        return @($blockers | Sort-Object -Unique)
    }

    # Tout ce que ces deux listes casseraient, une entrée par pack qui ne peut
    # pas partir : son nom, et les packs qui le tiennent. Vide est la réponse
    # ordinaire — la liste peut partir telle quelle.
    [object[]] GetRemovalConflicts([string[]]$installed, [string[]]$leaving, [string[]]$arriving) {
        $conflicts = @()
        foreach ($name in @($leaving)) {
            $who = @($this.GetBlockers($name, $installed, $leaving, $arriving))
            if ($who.Count -gt 0) { $conflicts += [PSCustomObject]@{ Name = $name; Blockers = $who } }
        }
        return @($conflicts)
    }
}
