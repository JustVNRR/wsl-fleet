# The two traversals of the console - instances and archives - through the
# navigation: a fake view records every screen it is shown, and a queue of
# answers lets one run walk several of them. What the checks read is the whole
# decision: the split between the live rows and the archives, the state and the
# orphan note, the docker word chosen from the row, the escape that climbs one
# step up and RE-READS the screen it returns to, an action's own cancel
# climbing back the same way, and the root's escape ending the run.
#
# Usage:  pwsh -NoProfile -File tests\presenters\browse-presenter-test.ps1
using module ..\..\src\windows\Presenters\Fleet\BrowsePresenter.psm1
using module ..\..\src\windows\Presenters\Fleet\NavigationPresenter.psm1
using module ..\..\src\windows\Presenters\ActionResult.psm1
using module ..\..\src\windows\Repositories\WslRepository.psm1
using module ..\..\src\windows\Repositories\InstanceRepository.psm1
using module ..\..\src\windows\Repositories\ArchiveRepository.psm1
using module ..\..\src\windows\Services\InstanceService.psm1
using module ..\..\src\windows\Entities\WslInstance.psm1
using module ..\..\src\windows\Entities\WslTheme.psm1
using module ..\..\src\windows\Views\cli\MenuCli.psm1
using module ..\support\common.psm1

class FakeBrowseView {
    [System.Collections.Generic.List[string]]$Orders
    [string]$Instance = ""
    [string]$Archive = ""
    [string]$Action = ""
    [System.Collections.Generic.List[string]]$InstanceQueue
    [System.Collections.Generic.List[string]]$ActionQueue

    FakeBrowseView() {
        $this.Orders = [System.Collections.Generic.List[string]]::new()
        $this.InstanceQueue = [System.Collections.Generic.List[string]]::new()
        $this.ActionQueue = [System.Collections.Generic.List[string]]::new()
    }

    [object] PickInstance([object[]]$rows, [object[]]$orphans, [string[]]$running) {
        $this.Orders.Add("instances $($rows.Count) orphans=$($orphans.Count) running=$($running -join ',')")
        $wanted = $this.Instance
        if ($this.InstanceQueue.Count -gt 0) { $wanted = $this.InstanceQueue[0]; $this.InstanceQueue.RemoveAt(0) }
        foreach ($row in @($rows)) { if ("$($row.Name)" -eq $wanted) { return $row } }
        return $null
    }
    [object] PickArchive([object[]]$archives) {
        $this.Orders.Add("archives $($archives.Count)")
        foreach ($row in @($archives)) { if ("$($row.Name)" -eq $this.Archive) { return $row } }
        return $null
    }
    [object] PickAction([string]$title, [object[]]$actions) {
        $this.Orders.Add("actions $title : $((@($actions) | ForEach-Object { $_.Key }) -join ',')")
        $wanted = $this.Action
        if ($this.ActionQueue.Count -gt 0) { $wanted = $this.ActionQueue[0]; $this.ActionQueue.RemoveAt(0) }
        foreach ($item in @($actions)) { if ("$($item.Key)" -eq $wanted) { return $item } }
        return $null
    }
    [void] ShowNoInstances([object[]]$orphans) { $this.Orders.Add("no-instances orphans=$($orphans.Count)") }
    [void] ShowNoArchives() { $this.Orders.Add("no-archives") }
}

$ErrorActionPreference = "Stop"

$global:Failures = 0

$World = Join-Path ([System.IO.Path]::GetTempPath()) ("browse-presenter-" + [Guid]::NewGuid().ToString("N"))
$env:USERPROFILE = $World
$env:LOCALAPPDATA = Join-Path $World "LocalAppData"
$env:APPDATA = Join-Path $World "AppData"
New-Item -ItemType Directory -Path $env:LOCALAPPDATA -Force | Out-Null
New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
$Root = Join-Path $World "WSL"
$Instance = "bench-agent"
$Second = "bench-other"
$OrphanFolder = Join-Path $Root "left-behind"

function New-InstanceFolder([string]$name) {
    $folder = Join-Path $Root $name
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $folder ".wsl-fleet") -Force | Out-Null
    Set-Content -Path (Join-Path $folder "ext4.vhdx") -Value "fake-disk" -NoNewline
}

function Reset-World {
    Remove-Item -Recurse -Force $Root -ErrorAction SilentlyContinue
    New-InstanceFolder $Instance
    $Seeded = Join-Path $Root "archives\$($Instance)_archive"
    New-Item -ItemType Directory -Path $Seeded -Force | Out-Null
    Set-Content -Path (Join-Path $Seeded "instance.json") -Encoding Utf8 -Value '{ "DefaultUser": "qtest" }'
    Set-Content -Path (Join-Path $Seeded "$($Instance)_archive.tar.gz") -Encoding Utf8 -Value "fake-tar"
}
Reset-World

$instances = [InstanceRepository]::new($Root)
$archives = [ArchiveRepository]::new((Join-Path $Root "archives"))
$docker = [FakeDocker]::new()
$fake = [FakeWsl]::new()
$fake.Distros = @($Instance)
$fake.Running = @($Instance)
$fake.Folders[$Instance] = (Join-Path $Root $Instance)
$service = [InstanceService]::new($instances, $archives, $fake, $null, $docker, $null, $null)

function New-ViewsRoot {
    return (Join-Path $PSScriptRoot "..\..\src\windows\Views")
}

$log = [System.Collections.Generic.List[string]]::new()
$presenters = @{ Log = $log }

function New-Action([string]$key, [string]$description) {
    return [MenuItemCli]::new($key, $description, { param($Name, $Presenters) $Presenters.Log.Add("run $Name"); [ActionResult]::Ok("Act : $Name") })
}

$live = @(
    (New-Action "shell" "open a shell inside an instance"),
    (New-Action "compact" "reclaim the space an instance has freed"),
    (New-Action "unregister" "remove an instance")
)
$registerAction = New-Action "register_docker" "register an instance with Docker Desktop"
$unregisterAction = New-Action "unregister_docker" "take an instance out of Docker Desktop"
$archiveActions = @(
    (New-Action "restore" "rebuild an instance from an archive"),
    (New-Action "delete_archive" "delete an archive")
)

$presenter = [BrowsePresenter]::new($service, (New-ViewsRoot), "cli", $live, $registerAction, $unregisterAction, $archiveActions)
$nav = [NavigationPresenter]::new($presenter, $null)

try {
    # ---- instances ---------------------------------------------------------

    $view = [FakeBrowseView]::new()
    $presenter.Views = @{ "Browse" = $view }

    # 1. One live instance, one orphan, one running: the menu gets the live
    # row, the orphan count and the state; the actions come in the house
    # order, the docker word last before unregister when the row is not in
    # Docker Desktop - and the action runs with the name already picked.
    New-Item -ItemType Directory -Path $OrphanFolder -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $OrphanFolder ".wsl-fleet") -Force | Out-Null
    $view.Orders.Clear()
    $log.Clear()
    $view.Instance = $Instance
    $view.Action = "shell"
    $result = $nav.Run("instances", $presenters)
    Check "the instances menu gets the live row and the orphan" ($view.Orders[0]) "instances 1 orphans=1 running=$Instance"
    Check "  ... and the actions in order, register before unregister" ($view.Orders[1]) "actions Availables actions for 'bench-agent' : shell,compact,register_docker,unregister"
    Check "  ... the action ran with the picked name" ($log -join " | ") "run $Instance"
    Check "  ... and its result is the run's" "$($result.Status)/$($result.Message)" "Ok/Act : $Instance"
    Remove-Item -Recurse -Force $OrphanFolder -ErrorAction SilentlyContinue

    # 2. A row Docker knows: the word swaps, unregister_docker in its place.
    $docker.States[$Instance] = "yes"
    $view.Orders.Clear()
    $view.Action = "unregister_docker"
    $result = $nav.Run("instances", $presenters)
    Check "a registered row offers unregister_docker" ($view.Orders[1]) "actions Availables actions for 'bench-agent' : shell,compact,unregister_docker,unregister"
    Check "  ... and it goes" "$($result.Status)/$($result.Message)" "Ok/Act : $Instance"
    $docker.States.Clear()

    # 3. The escape at the instance menu: the root, so the run ends.
    $view.Orders.Clear()
    $log.Clear()
    $view.Instance = ""
    $result = $nav.Run("instances", $presenters)
    Check "an escape at the root ends the run" "$($result.Status)/$($result.Message)" "Ok/Instances : cancelled"
    Check "  ... after the menu alone" ($view.Orders -join " | ") "instances 1 orphans=0 running=$Instance"
    Check "  ... and nothing ran" $log.Count 0

    # 4. The escape at the actions climbs one step: the menu comes back, and
    # the pick is asked again.
    $view.Orders.Clear()
    $log.Clear()
    $view.Instance = $Instance
    $view.Action = ""
    $view.ActionQueue.Add("")
    $view.ActionQueue.Add("shell")
    $result = $nav.Run("instances", $presenters)
    Check "an escape at the actions climbs to the menu, relit" ($view.Orders -join " | ") "instances 1 orphans=0 running=$Instance | actions Availables actions for 'bench-agent' : shell,compact,register_docker,unregister | instances 1 orphans=0 running=$Instance | actions Availables actions for 'bench-agent' : shell,compact,register_docker,unregister"
    Check "  ... then the second pick goes" "$($result.Status)/$($result.Message)" "Ok/Act : $Instance"
    Check "  ... and only the second ran" ($log -join " | ") "run $Instance"

    # 5. An action that cancels climbs back the same way - and the menu it
    # returns to is RE-READ: the world grew while the action ran.
    Reset-World
    $fake.Distros = @($Instance)
    $view.Orders.Clear()
    $log.Clear()
    $grow = [MenuItemCli]::new("compact", "reclaim the space an instance has freed", {
        param($Name, $Presenters)
        $Presenters.Log.Add("grow")
        New-InstanceFolder $Second
        $fake.Distros = @($Instance, $Second)
        $fake.Folders[$Second] = (Join-Path $Root $Second)
        [ActionResult]::Ok("Act : cancelled")
    })
    $presenter5 = [BrowsePresenter]::new($service, (New-ViewsRoot), "cli", @($grow), $registerAction, $unregisterAction, $archiveActions)
    $presenter5.Views = @{ "Browse" = $view }
    $nav5 = [NavigationPresenter]::new($presenter5, $null)
    $view.Instance = ""
    $view.InstanceQueue.Add($Instance)
    $view.InstanceQueue.Add("")
    $view.ActionQueue.Add("compact")
    $result = $nav5.Run("instances", $presenters)
    Check "a cancelled action comes back to the menu, re-read on the climb" ($view.Orders -join " | ") "instances 1 orphans=0 running=$Instance | actions Availables actions for 'bench-agent' : compact | actions Availables actions for 'bench-agent' : compact | instances 2 orphans=0 running=$Instance"
    Check "  ... the action ran once" ($log -join " | ") "grow"
    Check "  ... and the escape then meets the root" "$($result.Status)/$($result.Message)" "Ok/Instances : cancelled"
    $fake.Distros = @($Instance)
    Remove-Item -Recurse -Force (Join-Path $Root $Second) -ErrorAction SilentlyContinue

    $presenter = [BrowsePresenter]::new($service, (New-ViewsRoot), "cli", $live, $registerAction, $unregisterAction, $archiveActions)
    $presenter.Views = @{ "Browse" = $view }
    $nav = [NavigationPresenter]::new($presenter, $null)

    # 6. Two live rows, the second picked: the title is its own.
    New-InstanceFolder $Second
    $fake.Distros = @($Instance, $Second)
    $fake.Folders[$Second] = (Join-Path $Root $Second)
    $view.Orders.Clear()
    $view.Instance = $Second
    $view.Action = "compact"
    $result = $nav.Run("instances", $presenters)
    Check "two rows are two" ($view.Orders[0]) "instances 2 orphans=0 running=$Instance"
    Check "  ... and the second is its own pick" ($view.Orders[1]) "actions Availables actions for 'bench-other' : shell,compact,register_docker,unregister"
    $fake.Distros = @($Instance)
    Remove-Item -Recurse -Force (Join-Path $Root $Second) -ErrorAction SilentlyContinue

    # ---- archives ----------------------------------------------------------

    # 7. The archive row, and the two actions: restore runs with the name.
    $view.Orders.Clear()
    $log.Clear()
    $view.Archive = "$($Instance)_archive"
    $view.Action = "restore"
    $result = $nav.Run("archives", $presenters)
    Check "the archives menu gets the archive" ($view.Orders[0]) "archives 1"
    Check "  ... and the two actions" ($view.Orders[1]) "actions Availables actions for '$($Instance)_archive' : restore,delete_archive"
    Check "  ... the restore ran on it" ($log -join " | ") "run $($Instance)_archive"
    Check "  ... its result returned" "$($result.Status)/$($result.Message)" "Ok/Act : $($Instance)_archive"

    # 8. The escape at the archive actions climbs to the menu, relit.
    $view.Orders.Clear()
    $log.Clear()
    $view.Action = ""
    $view.ActionQueue.Add("")
    $view.ActionQueue.Add("delete_archive")
    $result = $nav.Run("archives", $presenters)
    Check "an escape at the archive actions climbs" ($view.Orders -join " | ") "archives 1 | actions Availables actions for '$($Instance)_archive' : restore,delete_archive | archives 1 | actions Availables actions for '$($Instance)_archive' : restore,delete_archive"
    Check "  ... then the delete goes" "$($result.Status)/$($result.Message)" "Ok/Act : $($Instance)_archive"

    # 9. An empty archives folder: said at the root, so the run ends.
    Remove-Item -Recurse -Force (Join-Path $Root "archives") -ErrorAction SilentlyContinue
    $view.Orders.Clear()
    $result = $nav.Run("archives", $presenters)
    Check "no archives is a fault" "$($result.Status)/$($result.Message)" "Nok/Archives : none"
    Check "  ... and it was painted" ($view.Orders -join " | ") "no-archives"

    # 10. An empty machine with a folder left behind: the orphan is said with
    # the refusal, and no menu is drawn.
    Reset-World
    $fake.Distros = @()
    Remove-Item -Recurse -Force (Join-Path $Root $Instance) -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $OrphanFolder -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $OrphanFolder ".wsl-fleet") -Force | Out-Null
    $view.Orders.Clear()
    $result = $nav.Run("instances", $presenters)
    Check "no instance is a fault" "$($result.Status)/$($result.Message)" "Nok/Instances : none"
    Check "  ... with the orphan said" ($view.Orders -join " | ") "no-instances orphans=1"
    $fake.Distros = @($Instance)
} finally {
    Remove-Item -Recurse -Force $World -ErrorAction SilentlyContinue
}

Write-Output ""
Write-Output ("failures: " + $global:Failures)
exit $global:Failures
