# ==============================================================================
# UN PACK, TEL QUE pack.conf LE DÉCLARE
# ==============================================================================
# Les champs sont hidden — cachés à l'IntelliSense, la discipline plutôt que le
# verrou — et la porte est la méthode : un couple Get/Set, la règle au Set. Le
# dossier se résout par le nom (la racine des packs + le nom), pack.conf se
# lit et s'écrit au PackRepo, et les règles du catalogue — qui requiert qui,
# qui s'offre à quelle famille — vivent au catalogue. Le façonnement suit la
# recette du dépôt : un With* par champ, à la chaîne — le lecteur de pack.conf
# mappe ses clés dessus.
class WslPack {
    hidden [string]$Name
    hidden [string]$Description

    # Ce qu'il requiert : un pack s'installe par-dessus ceux-là, et un
    # requirement arrive avant lui.
    hidden [string[]]$Requires = @()

    # `PACK_VISIBLE := no` retire un pack des questions : il voyage avec le
    # pack qui le requiert, et part avec le dernier.
    hidden [bool]$Offered = $true

    # La famille de distribution dont ses paquets viennent ; absent = debian.
    hidden [string]$Family = "debian"

    # La ligne montrée une fois installé.
    hidden [string]$Welcome

    WslPack() {}

    # --- Get/Set, la règle au Set ---------------------------------------------

    [string] GetName() { return $this.Name }
    [void] SetName([string]$name) {
        if ($name -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*$') {
            throw "'$name' is not usable as a pack name (letters, digits, '.', '_' and '-' only)."
        }
        $this.Name = $name
    }

    [string] GetDescription() { return $this.Description }
    [void] SetDescription([string]$text) { $this.Description = $text }

    [string[]] GetRequires() { return $this.Requires }
    # Chaque requirement est un nom de pack : la même règle, un par un.
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
    # La famille : la forme d'un nom d'os-release (debian, ubuntu) — pas de
    # caractères spéciaux.
    [void] SetFamily([string]$family) {
        if ($family -notmatch '^[a-z][a-z0-9-]*$') {
            throw "'$family' is not usable as a family (lowercase letters, digits and '-' only)."
        }
        $this.Family = $family
    }

    [string] GetWelcome() { return $this.Welcome }
    [void] SetWelcome([string]$text) { $this.Welcome = $text }

    # --- Fluent Builder Methods -----------------------------------------------

    # Un champ vide ne pose rien : la clé absente du pack.conf n'écrase pas ce
    # qui est déjà là. Chaque With* passe par le Set — les règles tiennent
    # dans la chaîne.
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

    # --------------------------------------------------------------------------

    # Le pack en une ligne — qui l'affiche décide où et quand.
    [string] ToString() {
        return "pack '$($this.Name)' ($($this.Family)) - $($this.Description)"
    }
}
