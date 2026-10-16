class WslPack {

    hidden [string]$Name
    hidden [string]$Description
    hidden [string[]]$Requires = @()
    hidden [bool]$Offered = $true
    hidden [string]$Family = "debian"
    hidden [string]$Welcome

    WslPack() {}

    [string] GetName() { return $this.Name }
    [void] SetName([string]$name) {
        if ($name -notmatch '^_?[A-Za-z0-9][A-Za-z0-9_.-]*$') {
            throw "'$name' is not usable as a pack name (a letter or digit first, then letters, digits, '.', '_' and '-'; a leading '_' for the template)."
        }
        $this.Name = $name
    }

    [string] GetDescription() { return $this.Description }
    [void] SetDescription([string]$text) { $this.Description = $text }

    [string[]] GetRequires() { return $this.Requires }
    [void] SetRequires([string[]]$packs) {
        if ($null -eq $packs) { $this.Requires = @(); return }
        foreach ($required in $packs) {
            if ($required -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*$') {
                throw "'$required' is not usable as a pack name (letters, digits, '.', '_' and '-' only)."
            }
        }
        $this.Requires = @($packs)
    }

    [bool] GetOffered() { return $this.Offered }
    [void] SetOffered([bool]$offered) { $this.Offered = $offered }

    [string] GetFamily() { return $this.Family }
    [void] SetFamily([string]$family) {
        if ($family -notmatch '^[a-z][a-z0-9-]*$') {
            throw "'$family' is not usable as a family (lowercase letters, digits and '-' only)."
        }
        $this.Family = $family
    }

    [string] GetWelcome() { return $this.Welcome }
    [void] SetWelcome([string]$text) { $this.Welcome = $text }

    [WslPack] WithName([string]$name) {
        if (-not $name) { return $this }
        $this.SetName($name)
        return $this
    }

    [WslPack] WithDescription([string]$text) {
        if (-not $text) { return $this }
        $this.SetDescription($text)
        return $this
    }

    [WslPack] WithRequires([string[]]$packs) {
        $this.SetRequires($packs)
        return $this
    }

    [WslPack] WithOffered([bool]$offered) {
        $this.SetOffered($offered)
        return $this
    }

    [WslPack] WithFamily([string]$family) {
        if (-not $family) { return $this }
        $this.SetFamily($family)
        return $this
    }

    [WslPack] WithWelcome([string]$text) {
        if (-not $text) { return $this }
        $this.SetWelcome($text)
        return $this
    }

    [string] ToString() {
        return "pack '$($this.Name)' ($($this.Family)) - $($this.Description)"
    }
}
