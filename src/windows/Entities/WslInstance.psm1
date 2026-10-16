using module .\WslTheme.psm1
using module .\WslPack.psm1

class WslInstance {
    hidden [string]$Name
    hidden [string]$DefaultUser = "root"
    hidden [bool]$IsArchive = $false
    hidden [WslTheme]$Theme
    hidden [WslPack[]]$Packs = @()
    hidden [datetime]$CreatedAt
    hidden [long]$Size = 0

    WslInstance() {}

    [string] GetName() { return $this.Name }
    [void] SetName([string]$name) {
        if ($name -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*$') {
            throw "'$name' is not usable as an instance name (letters, digits, '.', '_' and '-' only)."
        }
        $this.Name = $name
    }

    [string] GetDefaultUser() { return $this.DefaultUser }
    [void] SetDefaultUser([string]$user) { $this.DefaultUser = $user }

    [bool] GetIsArchive() { return $this.IsArchive }
    [void] SetIsArchive([bool]$archive) { $this.IsArchive = $archive }

    [WslTheme] GetTheme() { return $this.Theme }
    [void] SetTheme([WslTheme]$look) { $this.Theme = $look }

    [WslPack[]] GetPacks() { return $this.Packs }
    [void] SetPacks([WslPack[]]$packs) {
        $this.Packs = if ($null -eq $packs) { @() } else { @($packs) }
    }

    [datetime] GetCreatedAt() { return $this.CreatedAt }
    [void] SetCreatedAt([datetime]$moment) { $this.CreatedAt = $moment }

    [long] GetSize() { return $this.Size }
    [void] SetSize([long]$bytes) { $this.Size = $bytes }

    [string] ToString() {
        $ThemeLine = if ($this.Theme) { "$($this.Theme)" } else { "-" }
        $PacksLine = if ($this.Packs.Count -eq 0) { "none" } else { (($this.Packs | ForEach-Object { $_.GetName() }) -join ", ") }
        $Lines = @(
            "  * Distribution Name : $($this.Name)",
            "  * Default User      : $($this.DefaultUser)",
            "  * Look              : $ThemeLine",
            "  * Packs             : $PacksLine"
        )
        return ($Lines -join "`n")
    }
}
