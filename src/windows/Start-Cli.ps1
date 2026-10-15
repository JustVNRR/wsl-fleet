# ==============================================================================
# L'ENTRÉE DU CLI — LA RACINE DE LA CONSOLE
# ==============================================================================
# Le menu, le dispatch, la construction des services et des contrôleurs (le
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
using module .\Controllers\InstanceController.psm1
using module .\Controllers\FleetController.psm1
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
# sous Views\ : c'est CE dossier que les contrôleurs prennent pour racine.
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

# Les contrôleurs, au type « cli ».
$instanceController = [InstanceController]::new($instanceService, $ViewsRoot, "cli")
$fleetController = [FleetController]::new($fleetService, $ViewsRoot, "cli")

# Le geste, un bloc par commande : le contrôleur et le nom arrivent en
# paramètres, le bloc rend l'ActionResult du geste.
$gestures = [ordered]@{
    "list"           = { param($Instance, $Fleet, $Name) $Instance.List() }
    "build"          = { param($Instance, $Fleet, $Name) $Instance.Build() }
    "restart"        = { param($Instance, $Fleet, $Name) $Instance.Restart($Name) }
    "shell"          = { param($Instance, $Fleet, $Name) $Instance.Open($Name) }
    "add_pack"       = { param($Instance, $Fleet, $Name) $Instance.AddPack($Name) }
    "remove_pack"    = { param($Instance, $Fleet, $Name) $Instance.RemovePack($Name) }
    "manage_packs"   = { param($Instance, $Fleet, $Name) $Instance.ManagePacks($Name) }
    "theme"          = { param($Instance, $Fleet, $Name) $Instance.SetAppearance($Name) }
    "unregister"     = { param($Instance, $Fleet, $Name) $Instance.Remove($Name) }
    "archive"        = { param($Instance, $Fleet, $Name) $Instance.Archive($Name) }
    "restore"        = { param($Instance, $Fleet, $Name) $Instance.Restore($Name) }
    "duplicate"      = { param($Instance, $Fleet, $Name) $Instance.Duplicate($Name) }
    "shrink"         = { param($Instance, $Fleet, $Name) $Instance.Compact($Name) }
    "wslconfig"      = { param($Instance, $Fleet, $Name) $Fleet.WslConfig() }
    "migrate"        = { param($Instance, $Fleet, $Name) $Fleet.Migrate($Name) }

    # La corbeille d'une archive se dit par son nom : pas dans le menu, son
    # mot la route.
    "delete_archive" = { param($Instance, $Fleet, $Name) $Instance.DeleteArchive($Name) }
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
$menu = $menu.Add("shrink",       "reclaim the space an instance has freed",  $gestures["shrink"])
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
$result = & $item.Action $instanceController $fleetController "$Name"
if ($null -eq $result) { exit 1 }
if ("$($result.Status)" -eq "Nok") { exit 1 }
exit 0
