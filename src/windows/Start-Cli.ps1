# ==============================================================================
# L'ENTRÉE DU CLI — LA RACINE DE LA CONSOLE
# ==============================================================================
# Le menu, le dispatch, la construction des services et des presenters (le
# type « cli »), et le geste.
#
#   .\Start-Cli.ps1                le menu
#   .\Start-Cli.ps1 archive        archiver une instance
#   .\Start-Cli.ps1 restore wagon_archive   par son nom
#
# Le geste est un BLOC LITTÉRAL, exécuté par l'entrée à son propre cran —
# jamais une méthode de classe : un natif sous une méthode perd son terminal
# (mesuré — le whiptail d'une naissance devenait aveugle), et le code de
# sortie passe par l'entrée, lu de l'ActionResult du geste. Le bloc reçoit
# tout en paramètres : rien ne se lit par un nom au moment de l'appel (une
# clôture qui lisait par nom a marché sur une machine et rendu vide sur une
# autre — mesuré).
#
# Ce dont ce fichier nomme, déclaré ici : il tire ses modules lui-même.
using module .\Service\ServiceFactory.psm1
using module .\Presenters\Instance\ArchivePresenter.psm1
using module .\Presenters\Instance\RemovePresenter.psm1
using module .\Presenters\Instance\DeleteArchivePresenter.psm1
using module .\Presenters\Instance\CompactPresenter.psm1
using module .\Presenters\Instance\RestorePresenter.psm1
using module .\Presenters\Instance\DuplicatePresenter.psm1
using module .\Presenters\Instance\AddPackPresenter.psm1
using module .\Presenters\Instance\RemovePackPresenter.psm1
using module .\Presenters\Instance\ManagePacksPresenter.psm1
using module .\Presenters\Instance\SetAppearancePresenter.psm1
using module .\Presenters\Instance\BuildPresenter.psm1
using module .\Presenters\Instance\ListPresenter.psm1
using module .\Presenters\Instance\OpenPresenter.psm1
using module .\Presenters\Instance\RestartPresenter.psm1
using module .\Presenters\Fleet\MigratePresenter.psm1
using module .\Presenters\Fleet\WslConfigPresenter.psm1
using module .\Views\cli\MenuCli.psm1

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Command,

    # Le nom, quand il est là : les gestes le prennent en premier — sans lui,
    # la vue du geste demande.
    [Parameter(Position = 1)]
    [string]$Name = ""
)

# Les dossiers : la racine du dépôt, deux crans au-dessus. Les vues vivent
# sous Views\ : c'est CE dossier que les presenters prennent pour racine.
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Assets = Join-Path $RepoRoot "assets"
$distroTree = Join-Path $RepoRoot "src\distro"
if (-not (Test-Path $distroTree)) { $distroTree = "" }
$ViewsRoot = Join-Path $PSScriptRoot "Views"

# L'assemblage : la fabrique fait tout — la racine comprise, qu'elle
# demande à la flotte d'un passage. L'entrée ne voit jamais un dépôt.
$root = [ServiceFactory]::ResolveRoot($Assets, $distroTree)
$fleetService = [ServiceFactory]::CreateFleetService($root, $Assets, $distroTree)
$instanceService = [ServiceFactory]::CreateInstanceService($root, $Assets, $distroTree)

# Les presenters : un par vue, construits ici — objets légers, la vue naît au
# premier geste. Le « cli » est le type d'UI, comme le « wpf » de la fenêtre.
$presenters = @{
    Archive       = [ArchivePresenter]::new($instanceService, $ViewsRoot, "cli")
    Remove        = [RemovePresenter]::new($instanceService, $ViewsRoot, "cli")
    DeleteArchive = [DeleteArchivePresenter]::new($instanceService, $ViewsRoot, "cli")
    Compact       = [CompactPresenter]::new($instanceService, $ViewsRoot, "cli")
    Restore       = [RestorePresenter]::new($instanceService, $ViewsRoot, "cli")
    Duplicate     = [DuplicatePresenter]::new($instanceService, $ViewsRoot, "cli")
    AddPack       = [AddPackPresenter]::new($instanceService, $ViewsRoot, "cli")
    RemovePack    = [RemovePackPresenter]::new($instanceService, $ViewsRoot, "cli")
    ManagePacks   = [ManagePacksPresenter]::new($instanceService, $ViewsRoot, "cli")
    SetAppearance = [SetAppearancePresenter]::new($instanceService, $ViewsRoot, "cli")
    Build         = [BuildPresenter]::new($instanceService, $ViewsRoot, "cli")
    List          = [ListPresenter]::new($instanceService, $ViewsRoot, "cli")
    Open          = [OpenPresenter]::new($instanceService, $ViewsRoot, "cli")
    Restart       = [RestartPresenter]::new($instanceService, $ViewsRoot, "cli")
    Migrate       = [MigratePresenter]::new($fleetService, $ViewsRoot, "cli")
    WslConfig     = [WslConfigPresenter]::new($fleetService, $ViewsRoot, "cli")
}

# Le geste, un bloc par commande : le nom et la table des presenters arrivent
# en paramètres, le bloc rend l'ActionResult du geste.
$gestures = [ordered]@{
    "list"           = { param($Name, $Presenters) $Presenters.List.Run() }
    "build"          = { param($Name, $Presenters) $Presenters.Build.Run() }
    "restart"        = { param($Name, $Presenters) $Presenters.Restart.Run($Name) }
    "shell"          = { param($Name, $Presenters) $Presenters.Open.Run($Name) }
    "add_pack"       = { param($Name, $Presenters) $Presenters.AddPack.Run($Name) }
    "remove_pack"    = { param($Name, $Presenters) $Presenters.RemovePack.Run($Name) }
    "manage_packs"   = { param($Name, $Presenters) $Presenters.ManagePacks.Run($Name) }
    "theme"          = { param($Name, $Presenters) $Presenters.SetAppearance.Run($Name) }
    "unregister"     = { param($Name, $Presenters) $Presenters.Remove.Run($Name) }
    "archive"        = { param($Name, $Presenters) $Presenters.Archive.Run($Name) }
    "restore"        = { param($Name, $Presenters) $Presenters.Restore.Run($Name) }
    "duplicate"      = { param($Name, $Presenters) $Presenters.Duplicate.Run($Name) }
    "compact"         = { param($Name, $Presenters) $Presenters.Compact.Run($Name) }
    "wslconfig"      = { param($Name, $Presenters) $Presenters.WslConfig.Run() }
    "migrate"        = { param($Name, $Presenters) $Presenters.Migrate.Run($Name) }

    # La corbeille d'une archive se dit par son nom : pas dans le menu, son
    # mot la route.
    "delete_archive" = { param($Name, $Presenters) $Presenters.DeleteArchive.Run($Name) }
}

# Le menu : un rang par commande — le mot, la ligne, le bloc. L'ordre est
# celui de la vie d'une instance ; la corbeille d'archive n'y est pas, comme
# avant — un nom la nomme.
$console = [ConsoleCli]::new()
$menu = [MenuCli]::new("WSL Fleet CLI")
$menu = $menu.Add("list",         "list our instances and the archives",      $gestures["list"])
$menu = $menu.Add("build",        "build an instance from the image",         $gestures["build"])
$menu = $menu.Add("restart",      "restart an instance",                      $gestures["restart"])
$menu = $menu.Add("shell",        "open a shell inside an instance",          $gestures["shell"])
$menu = $menu.Add("add_pack",     "install a pack into an instance",          $gestures["add_pack"])
$menu = $menu.Add("remove_pack",  "uninstall a pack from an instance",        $gestures["remove_pack"])
$menu = $menu.Add("manage_packs", "choose the packs an instance should carry", $gestures["manage_packs"])
$menu = $menu.Add("theme",        "choose the icon, font and colours",        $gestures["theme"])
$menu = $menu.Add("unregister",   "remove an instance",                       $gestures["unregister"])
$menu = $menu.Add("archive",      "write an instance to a named archive",     $gestures["archive"])
$menu = $menu.Add("restore",      "rebuild an instance from an archive",      $gestures["restore"])
$menu = $menu.Add("duplicate",    "copy an instance under another name",      $gestures["duplicate"])
$menu = $menu.Add("compact",       "reclaim the space an instance has freed",  $gestures["compact"])
$menu = $menu.Add("wslconfig",    "open the Windows-wide WSL settings",       $gestures["wslconfig"])
$menu = $menu.Add("migrate",      "move the fleet to another folder",         $gestures["migrate"])

# Avec un mot, la ligne de commande le route ; sans, le menu le demande —
# flèches et Entrée, Échap pour abandonner.
$item = $null
if ($Command) {
    $item = $menu.Dispatch($Command)
    if (-not $item) {
        # Un mot que le menu ne porte pas peut encore être un geste — la
        # corbeille d'archive, par son nom.
        if ($gestures.Contains("$Command".ToLower())) {
            $item = [PSCustomObject]@{ Key = "$Command".ToLower(); Action = $gestures["$Command".ToLower()] }
        }
    }
    if (-not $item) {
        $console.Line("", "")
        $console.Line("[ABORT] Invalid command '$Command'. Available commands:", "error")
        foreach ($key in @($gestures.Keys)) { if ($key -ne "delete_archive") { $console.Line("          $key", "hint") } }
        exit 1
    }
} else {
    $item = $menu.Prompt()
    if (-not $item) { exit 1 }
}

# Le geste court — à ce cran, pas dans une méthode — et son ActionResult dit
# le code de sortie : Nok échoue, Ok passe, l'abandon compris (rien n'a
# échoué).
$result = & $item.Action "$Name" $presenters
if ($null -eq $result) { exit 1 }
if ("$($result.Status)" -eq "Nok") { exit 1 }
exit 0
