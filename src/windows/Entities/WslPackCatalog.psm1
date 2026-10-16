using module .\WslPack.psm1

class WslPackCatalog {

    hidden [WslPack[]]$Packs = @()

    WslPackCatalog() {}

    [WslPack[]] GetPacks() { return $this.Packs }
    [void] SetPacks([WslPack[]]$packs) {
        $this.Packs = @($packs | Where-Object { $null -ne $_ })
    }

    [WslPack] GetPack([string]$name) {
        return @($this.Packs | Where-Object { $_.GetName() -eq $name })[0]
    }

    [WslPack[]] OfferedFor([string]$family) {
        if (-not $family) { return @($this.Packs | Where-Object { $_.GetOffered() }) }
        return @($this.Packs | Where-Object { $_.GetOffered() -and $_.GetFamily() -eq $family })
    }

    [string[]] ResolveSelection([string[]]$names, [string[]]$installed) {
        $seen = @{}
        $ordered = New-Object System.Collections.ArrayList
        foreach ($name in @($names)) {
            $this.AddRequires($name, $installed, $seen, $ordered)
        }
        return @($ordered)
    }

    hidden [void] AddRequires([string]$name, [string[]]$installed, [hashtable]$seen, [System.Collections.ArrayList]$ordered) {
        if ($seen.ContainsKey($name)) { return }
        $seen[$name] = $true

        $pack = $this.GetPack($name)
        if ($null -eq $pack) { return }

        foreach ($need in @($pack.GetRequires())) {
            $this.AddRequires($need, $installed, $seen, $ordered)
        }

        if ($installed -notcontains $name) { [void]$ordered.Add($name) }
    }

    [string[]] ResolveRemoval([string[]]$installed, [string[]]$leaving, [string[]]$arriving) {
        $gone = New-Object System.Collections.ArrayList
        foreach ($name in @($leaving)) { [void]$gone.Add($name) }

        do {
            $added = 0
            $remaining = @($installed | Where-Object { $gone -notcontains $_ }) + @($arriving)

            foreach ($name in @($installed)) {
                if ($gone -contains $name) { continue }

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

    [string[]] GetBlockers([string]$name, [string[]]$installed, [string[]]$leaving, [string[]]$arriving) {
        $standing = @(@($installed) + @($arriving) | Where-Object { $leaving -notcontains $_ -and $_ -ne $name })
        $blockers = @()
        foreach ($other in $standing) {
            $pack = $this.GetPack($other)
            if ($null -ne $pack -and @($pack.GetRequires()) -contains $name) { $blockers += $other }
        }
        return @($blockers | Sort-Object -Unique)
    }

    [object[]] GetRemovalConflicts([string[]]$installed, [string[]]$leaving, [string[]]$arriving) {
        $conflicts = @()
        foreach ($name in @($leaving)) {
            $who = @($this.GetBlockers($name, $installed, $leaving, $arriving))
            if ($who.Count -gt 0) { $conflicts += [PSCustomObject]@{ Name = $name; Blockers = $who } }
        }
        return @($conflicts)
    }
}
