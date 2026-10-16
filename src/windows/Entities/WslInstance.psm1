# ==============================================================================
# UNE INSTANCE
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout un type qu'il a tiré
# lui-même.
using module .\WslTheme.psm1
using module .\WslPack.psm1

# Une distribution — vivante, ou à l'arrêt sous forme d'archive (la même
# classe, IsArchive vrai, un nom suffixé). Sept champs, hidden — cachés à
# l'IntelliSense, la discipline plutôt que le verrou — servis par un couple
# Get/Set, la règle au Set ; le thème entier par GetTheme/SetTheme (ses parts
# vivent sur lui) ; ToString() — et rien d'autre : les gestes sont aux
# services, les lectures aux dépôts, et les chemins se résolvent par le nom.
class WslInstance {
    hidden [string]$Name
    hidden [string]$DefaultUser = "root"
    hidden [bool]$IsArchive = $false
    hidden [WslTheme]$Theme
    hidden [WslPack[]]$Packs = @()
    hidden [datetime]$CreatedAt
    hidden [long]$Size = 0

    WslInstance() {}

    # --- Get/Set, la règle au Set ---------------------------------------------

    [string] GetName() { return $this.Name }
    # La règle du nom est au setter : un nom refusé jette. Aucun vérificateur
    # public — le cli et la gui font leur contrôle sur le contrat (tell, don't
    # ask), la classe, elle, jette.
    [void] SetName([string]$name) {
        if ($name -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*$') {
            throw "'$name' is not usable as an instance name (letters, digits, '.', '_' and '-' only)."
        }
        $this.Name = $name
    }

    # L'utilisateur créé par la naissance ; root quand rien n'est précisé.
    [string] GetDefaultUser() { return $this.DefaultUser }
    [void] SetDefaultUser([string]$user) { $this.DefaultUser = $user }

    # Vrai pour une archive — instanciée sous le nom suffixé (wagon →
    # wagon_archive) ; dossier et tar se résolvent par ce nom.
    [bool] GetIsArchive() { return $this.IsArchive }
    [void] SetIsArchive([bool]$archive) { $this.IsArchive = $archive }

    # L'apparence née avec — le thème entier par sa porte ; ses parts (police,
    # couleurs, dessin de l'icône) se changent sur lui (WslTheme.SetFont,
    # SetColourScheme, SetIcon).
    [WslTheme] GetTheme() { return $this.Theme }
    [void] SetTheme([WslTheme]$look) { $this.Theme = $look }

    # Les packs portés.
    [WslPack[]] GetPacks() { return $this.Packs }
    [void] SetPacks([WslPack[]]$packs) {
        $this.Packs = if ($null -eq $packs) { @() } else { @($packs) }
    }

    # La date de création.
    [datetime] GetCreatedAt() { return $this.CreatedAt }
    [void] SetCreatedAt([datetime]$moment) { $this.CreatedAt = $moment }

    # La taille : le vhdx, ou le tar d'une archive.
    [long] GetSize() { return $this.Size }
    [void] SetSize([long]$bytes) { $this.Size = $bytes }

    # --------------------------------------------------------------------------

    # L'instance en un bloc de lignes — qui la montre décide où et quand.
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
