# The two traversals the console gained: instances and archives, driven by a
# fake view - each pick recorded, each action a stub of its own. The rows are
# the service's own over a world of the suite's, so what the checks read is
# the presenter's whole decision: the split between the live instances and the
# archives, the state passed with the columns, the orphan note, the docker
# word chosen from the row, and the action run with the name already picked.
#
# Usage:  pwsh -NoProfile -File tests\presenters\browse-presenter-test.ps1
using module ..\..\src\windows\Presenters\Fleet\BrowsePresenter.psm1
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

    FakeBrowseView() { $this.Orders = [System.Collections.Generic.List[string]]::new() }

    [object] PickInstance([object[]]$rows, [object[]]$orphans, [string[]]$running) {
        $this.Orders.Add("instances $($rows.Count) orphans=$($orphans.Count) running=$($running -join ',')")
        foreach ($row in @($rows)) { if ("$($row.Name)" -eq $this.Instance) { return $row } }
        return $null
    }
    [object] PickArchive([object[]]$archives) {
        $this.Orders.Add("archives $($archives.Count)")
        foreach ($row in @($archives)) { if ("$($row.Name)" -eq $this.Archive) { return $row } }
        return $null
    }
    [object] PickAction([string]$title, [object[]]$actions) {
        $this.Orders.Add("actions $title : $((@($actions) | ForEach-Object { $_.Key }) -join ',')")
        foreach ($item in @($actions)) { if ("$($item.Key)" -eq $this.Action) { return $item } }
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
    $result = $presenter.Run($presenters, "instances")
    Check "the instances menu gets the live row and the orphan" ($view.Orders[0]) "instances 1 orphans=1 running=$Instance"
    Check "  ... and the actions in order, register before unregister" ($view.Orders[1]) "actions What to do with 'bench-agent' : shell,compact,register_docker,unregister"
    Check "  ... the action ran with the picked name" ($log -join " | ") "run $Instance"
    Check "  ... and its result is the browser's" "$($result.Status)/$($result.Message)" "Ok/Act : $Instance"
    Remove-Item -Recurse -Force $OrphanFolder -ErrorAction SilentlyContinue

    # 2. A row Docker knows: the word swaps, unregister_docker in its place.
    $docker.States[$Instance] = "yes"
    $view.Orders.Clear()
    $view.Action = "unregister_docker"
    $result = $presenter.Run($presenters, "instances")
    Check "a registered row offers unregister_docker" ($view.Orders[1]) "actions What to do with 'bench-agent' : shell,compact,unregister_docker,unregister"
    Check "  ... and it goes" "$($result.Status)/$($result.Message)" "Ok/Act : $Instance"
    $docker.States.Clear()

    # 3. The escape at the instance menu: nothing is asked further.
    $view.Orders.Clear()
    $log.Clear()
    $view.Instance = ""
    $result = $presenter.Run($presenters, "instances")
    Check "an escape at the menu cancels" "$($result.Status)/$($result.Message)" "Ok/Instances : cancelled"
    Check "  ... after the menu alone" ($view.Orders -join " | ") "instances 1 orphans=0 running=$Instance"
    Check "  ... and nothing ran" $log.Count 0

    # 4. The escape at the action menu: the instance was picked, and stops
    # there.
    $view.Orders.Clear()
    $view.Instance = $Instance
    $view.Action = ""
    $result = $presenter.Run($presenters, "instances")
    Check "an escape at the actions cancels" "$($result.Status)/$($result.Message)" "Ok/Instances : cancelled"
    Check "  ... the title carries the picked name" ($view.Orders[1]) "actions What to do with 'bench-agent' : shell,compact,register_docker,unregister"

    # 5. Two live rows, the second picked: the title is its own.
    New-InstanceFolder $Second
    $fake.Distros = @($Instance, $Second)
    $fake.Folders[$Second] = (Join-Path $Root $Second)
    $view.Orders.Clear()
    $view.Instance = $Second
    $view.Action = "compact"
    $result = $presenter.Run($presenters, "instances")
    Check "two rows are two" ($view.Orders[0]) "instances 2 orphans=0 running=$Instance"
    Check "  ... and the second is its own pick" ($view.Orders[1]) "actions What to do with 'bench-other' : shell,compact,register_docker,unregister"
    $fake.Distros = @($Instance)
    Remove-Item -Recurse -Force (Join-Path $Root $Second) -ErrorAction SilentlyContinue

    # ---- archives ----------------------------------------------------------

    # 6. The archive row, and the two actions: restore runs with the name.
    $view.Orders.Clear()
    $log.Clear()
    $view.Archive = "$($Instance)_archive"
    $view.Action = "restore"
    $result = $presenter.Run($presenters, "archives")
    Check "the archives menu gets the archive" ($view.Orders[0]) "archives 1"
    Check "  ... and the two actions" ($view.Orders[1]) "actions What to do with '$($Instance)_archive' : restore,delete_archive"
    Check "  ... the restore ran on it" ($log -join " | ") "run $($Instance)_archive"
    Check "  ... its result returned" "$($result.Status)/$($result.Message)" "Ok/Act : $($Instance)_archive"

    # 7. Delete is the other pick, and it goes the same way.
    $view.Orders.Clear()
    $log.Clear()
    $view.Action = "delete_archive"
    $result = $presenter.Run($presenters, "archives")
    Check "the delete pick goes" "$($result.Status)/$($result.Message)" "Ok/Act : $($Instance)_archive"
    Check "  ... and nothing else was asked" ($view.Orders.Count) 2

    # 8. An empty archives folder: said, and a fault.
    Remove-Item -Recurse -Force (Join-Path $Root "archives") -ErrorAction SilentlyContinue
    $view.Orders.Clear()
    $result = $presenter.Run($presenters, "archives")
    Check "no archives is a fault" "$($result.Status)/$($result.Message)" "Nok/Archives : none"
    Check "  ... and it was painted" ($view.Orders -join " | ") "no-archives"

    # 9. An empty machine with a folder left behind: the orphan is said with
    # the refusal, and no menu is drawn.
    Reset-World
    $fake.Distros = @()
    Remove-Item -Recurse -Force (Join-Path $Root $Instance) -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $OrphanFolder -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $OrphanFolder ".wsl-fleet") -Force | Out-Null
    $view.Orders.Clear()
    $result = $presenter.Run($presenters, "instances")
    Check "no instance is a fault" "$($result.Status)/$($result.Message)" "Nok/Instances : none"
    Check "  ... with the orphan said" ($view.Orders -join " | ") "no-instances orphans=1"
    $fake.Distros = @($Instance)
} finally {
    Remove-Item -Recurse -Force $World -ErrorAction SilentlyContinue
}

Write-Output ""
Write-Output ("failures: " + $global:Failures)
exit $global:Failures
