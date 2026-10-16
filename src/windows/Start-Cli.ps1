using module .\Services\ServiceFactory.psm1
using module .\Presenters\Instance\ArchivePresenter.psm1
using module .\Presenters\Instance\RemovePresenter.psm1
using module .\Presenters\Instance\DeleteArchivePresenter.psm1
using module .\Presenters\Instance\CompactPresenter.psm1
using module .\Presenters\Instance\RestorePresenter.psm1
using module .\Presenters\Instance\DuplicatePresenter.psm1
using module .\Presenters\Instance\ManagePacksPresenter.psm1
using module .\Presenters\Instance\SetAppearancePresenter.psm1
using module .\Presenters\Instance\RegisterDockerPresenter.psm1
using module .\Presenters\Instance\UnregisterDockerPresenter.psm1
using module .\Presenters\Instance\BuildPresenter.psm1
using module .\Presenters\Fleet\BrowsePresenter.psm1
using module .\Presenters\Fleet\SettingsPresenter.psm1
using module .\Presenters\Instance\OpenPresenter.psm1
using module .\Presenters\Instance\RestartPresenter.psm1
using module .\Presenters\Fleet\MigratePresenter.psm1
using module .\Presenters\Fleet\WslConfigPresenter.psm1
using module .\Views\cli\MenuCli.psm1

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Command,

    [Parameter(Position = 1)]
    [string]$Name = ""
)

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Assets = Join-Path $RepoRoot "assets"
$distroTree = Join-Path $RepoRoot "src\distro"
if (-not (Test-Path $distroTree)) { $distroTree = "" }
$ViewsRoot = Join-Path $PSScriptRoot "Views"

$root = [ServiceFactory]::ResolveRoot($Assets, $distroTree)
$fleetService = [ServiceFactory]::CreateFleetService($root, $Assets, $distroTree)
$instanceService = [ServiceFactory]::CreateInstanceService($root, $Assets, $distroTree)
$catalogueService = [ServiceFactory]::CreatePackCatalogService($Assets, $distroTree)

$gestures = [ordered]@{
    "build"          = { param($Name, $Presenters) $Presenters.Build.Run() }
    "settings"       = { param($Name, $Presenters) $Presenters.Settings.Run($Presenters) }
    "instances"      = { param($Name, $Presenters) $Presenters.Browse.Run($Presenters, "instances") }
    "archives"       = { param($Name, $Presenters) $Presenters.Browse.Run($Presenters, "archives") }

    "restart"        = { param($Name, $Presenters) $Presenters.Restart.Run($Name) }
    "shell"          = { param($Name, $Presenters) $Presenters.Open.Run($Name) }
    "manage_packs"   = { param($Name, $Presenters) $Presenters.ManagePacks.Run($Name) }
    "theme"          = { param($Name, $Presenters) $Presenters.SetAppearance.Run($Name) }
    "register_docker"   = { param($Name, $Presenters) $Presenters.RegisterDocker.Run($Name) }
    "unregister_docker" = { param($Name, $Presenters) $Presenters.UnregisterDocker.Run($Name) }
    "unregister"     = { param($Name, $Presenters) $Presenters.Remove.Run($Name) }
    "archive"        = { param($Name, $Presenters) $Presenters.Archive.Run($Name) }
    "restore"        = { param($Name, $Presenters) $Presenters.Restore.Run($Name) }
    "duplicate"      = { param($Name, $Presenters) $Presenters.Duplicate.Run($Name) }
    "compact"        = { param($Name, $Presenters) $Presenters.Compact.Run($Name) }
    "migrate"        = { param($Name, $Presenters) $Presenters.Migrate.Run($Name) }
    "wslconfig"      = { param($Name, $Presenters) $Presenters.WslConfig.Run() }

    "delete_archive" = { param($Name, $Presenters) $Presenters.DeleteArchive.Run($Name) }
}

$actions = @{
    "shell"             = [MenuItemCli]::new("shell", "open a shell inside an instance", $gestures["shell"])
    "restart"           = [MenuItemCli]::new("restart", "restart an instance", $gestures["restart"])
    "manage_packs"      = [MenuItemCli]::new("manage_packs", "choose the packs an instance should carry", $gestures["manage_packs"])
    "theme"             = [MenuItemCli]::new("theme", "choose the icon, font and colours", $gestures["theme"])
    "duplicate"         = [MenuItemCli]::new("duplicate", "copy an instance under another name", $gestures["duplicate"])
    "archive"           = [MenuItemCli]::new("archive", "write an instance to a named archive", $gestures["archive"])
    "compact"           = [MenuItemCli]::new("compact", "reclaim the space an instance has freed", $gestures["compact"])
    "migrate"           = [MenuItemCli]::new("migrate", "move the fleet to another folder", $gestures["migrate"])
    "wslconfig"         = [MenuItemCli]::new("wslconfig", "open the Windows-wide WSL settings", $gestures["wslconfig"])
    "register_docker"   = [MenuItemCli]::new("register_docker", "register an instance with Docker Desktop", $gestures["register_docker"])
    "unregister_docker" = [MenuItemCli]::new("unregister_docker", "take an instance out of Docker Desktop", $gestures["unregister_docker"])
    "unregister"        = [MenuItemCli]::new("unregister", "remove an instance", $gestures["unregister"])
    "restore"           = [MenuItemCli]::new("restore", "rebuild an instance from an archive", $gestures["restore"])
    "delete_archive"    = [MenuItemCli]::new("delete_archive", "delete an archive", $gestures["delete_archive"])
}

$console = [ConsoleCli]::new()
$menu = [MenuCli]::new("WSL Fleet CLI")
$menu = $menu.Add("build",     "build an instance from the image",     $gestures["build"])
$menu = $menu.Add("settings",  "the working folder, .wslconfig, and the packs catalog", $gestures["settings"])
$menu = $menu.Add("instances", "choose an instance and act on it",     $gestures["instances"])
$menu = $menu.Add("archives",  "choose an archive: restore or delete", $gestures["archives"])

$presenters = @{
    Archive       = [ArchivePresenter]::new($instanceService, $ViewsRoot, "cli")
    Remove        = [RemovePresenter]::new($instanceService, $ViewsRoot, "cli")
    DeleteArchive = [DeleteArchivePresenter]::new($instanceService, $ViewsRoot, "cli")
    Compact       = [CompactPresenter]::new($instanceService, $ViewsRoot, "cli")
    Restore       = [RestorePresenter]::new($instanceService, $ViewsRoot, "cli")
    Duplicate     = [DuplicatePresenter]::new($instanceService, $ViewsRoot, "cli")
    ManagePacks   = [ManagePacksPresenter]::new($instanceService, $ViewsRoot, "cli")
    SetAppearance = [SetAppearancePresenter]::new($instanceService, $ViewsRoot, "cli")
    RegisterDocker   = [RegisterDockerPresenter]::new($instanceService, $ViewsRoot, "cli")
    UnregisterDocker = [UnregisterDockerPresenter]::new($instanceService, $ViewsRoot, "cli")
    Build         = [BuildPresenter]::new($instanceService, $ViewsRoot, "cli")
    Open          = [OpenPresenter]::new($instanceService, $ViewsRoot, "cli")
    Restart       = [RestartPresenter]::new($instanceService, $ViewsRoot, "cli")
    Migrate       = [MigratePresenter]::new($fleetService, $ViewsRoot, "cli")
    WslConfig     = [WslConfigPresenter]::new($fleetService, $ViewsRoot, "cli")
}

$presenters.Browse = [BrowsePresenter]::new($instanceService, $ViewsRoot, "cli",
    @($actions["shell"], $actions["restart"], $actions["manage_packs"], $actions["theme"],
      $actions["duplicate"], $actions["archive"], $actions["compact"], $actions["unregister"]),
    $actions["register_docker"],
    $actions["unregister_docker"],
    @($actions["restore"], $actions["delete_archive"]))

$presenters.Settings = [SettingsPresenter]::new($catalogueService, $ViewsRoot, "cli",
    @($actions["migrate"], $actions["wslconfig"], [MenuItemCli]::new("availables packs", "edit, duplicate or delete a catalogue pack", $null)))

$item = $null
if ($Command) {
    $item = $menu.Dispatch($Command)
    if (-not $item) {
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

$result = & $item.Action "$Name" $presenters
if ($null -eq $result) { exit 1 }
if ("$($result.Status)" -eq "Nok") { exit 1 }
exit 0
