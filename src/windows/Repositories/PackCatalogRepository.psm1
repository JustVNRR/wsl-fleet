using module ..\Entities\WslPack.psm1

class PackCatalogRepository {

    hidden [string]$PacksRoot

    PackCatalogRepository([string]$packsRoot) {
        $this.PacksRoot = $packsRoot
    }

    [void] SeedFrom([string]$sourceRoot) {
        if ((Test-Path $this.PacksRoot) -or -not (Test-Path $sourceRoot)) { return }
        $null = New-Item -ItemType Directory -Path $this.PacksRoot -Force
        foreach ($dir in (Get-ChildItem -Path $sourceRoot -Directory)) {
            Copy-Item -LiteralPath $dir.FullName -Destination $this.PacksRoot -Recurse
        }
    }

    [string] GetFolder([string]$packName) {
        return (Join-Path $this.PacksRoot $packName)
    }

    [WslPack[]] GetAllPacks() {
        $packs = @()
        if (-not (Test-Path $this.PacksRoot)) { return @() }
        foreach ($dir in (Get-ChildItem -Path $this.PacksRoot -Directory | Sort-Object Name)) {
            if (-not (Test-Path (Join-Path $dir.FullName "pack.conf"))) { continue }
            $packs += $this.GetPack($dir.FullName)
        }
        return @($packs)
    }

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

    [void] CopyPack([string]$sourceName, [string]$newName) {
        if (Test-Path $this.GetFolder($newName)) {
            throw "A pack named '$newName' already lives in the catalogue."
        }
        Copy-Item -LiteralPath $this.GetFolder($sourceName) -Destination $this.GetFolder($newName) -Recurse -ErrorAction Stop
    }

    [void] DeletePack([string]$packName) {
        Remove-Item -LiteralPath $this.GetFolder($packName) -Recurse -Force -ErrorAction Stop
    }

    [void] OpenFolder([string]$packName) {
        Start-Process -FilePath $this.GetFolder($packName)
    }
}
