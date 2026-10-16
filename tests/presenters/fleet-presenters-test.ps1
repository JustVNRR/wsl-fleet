# The fleet of the fifth lot, driven by fake views: shell (open), restart,
# migrate and wslconfig - each presenter runs its whole conversation with no
# console anywhere, and every decision (the restart's yes, the three migrate
# refusals, the Dto-less gesture) is the presenter's.
#
# The services are the real ones over a world of the suite's own: a stand-in
# WslRepository recording every move, the root file in a redirected profile,
# and a stand-in FleetService method for the one gesture whose last call is a
# native (wslconfig opens the file in an editor) - so the four traversals run
# anywhere, the sandbox and the runner alike.
#
# Usage:  pwsh -NoProfile -File tests\presenters\fleet-presenters-test.ps1
using module ..\..\src\windows\Presenters\Instance\OpenPresenter.psm1
using module ..\..\src\windows\Presenters\Instance\RestartPresenter.psm1
using module ..\..\src\windows\Presenters\Fleet\MigratePresenter.psm1
using module ..\..\src\windows\Presenters\Fleet\WslConfigPresenter.psm1
using module ..\..\src\windows\Repositories\WslRepository.psm1
using module ..\..\src\windows\Repositories\InstanceRepository.psm1
using module ..\..\src\windows\Repositories\ArchiveRepository.psm1
using module ..\..\src\windows\Repositories\TerminalRepository.psm1
using module ..\..\src\windows\Repositories\DockerRepository.psm1
using module ..\..\src\windows\Repositories\ConfigRepository.psm1
using module ..\..\src\windows\Entities\WslInstance.psm1
using module ..\..\src\windows\Dtos\InstanceDto.psm1
using module ..\..\src\windows\Services\InstanceService.psm1
using module ..\..\src\windows\Services\FleetService.psm1
using module ..\support\common.psm1


# The gesture whose last step is a native - the .wslconfig editor - carries
# its seam here: the service method is faked, the rest of the fleet is
# the real one.
class FakeFleet : FleetService {
    [System.Collections.Generic.List[string]]$Called
    [string]$Path = "/tmp/fake-wslconfig"
    [bool]$Created = $true
    [string]$Refusal = ""

    FakeFleet([ConfigRepository]$config, [WslRepository]$wsl, [InstanceRepository]$instances,
              [ArchiveRepository]$archives, [InstanceService]$instanceService) : base($config, $wsl, $instances, $archives, $instanceService) {
        $this.Called = [System.Collections.Generic.List[string]]::new()
    }

    [WslConfigResponseDto] WslConfig() {
        $this.Called.Add("wslconfig")
        if ($this.Refusal) { throw $this.Refusal }
        $response = [WslConfigResponseDto]::new()
        $response.Path = $this.Path
        $response.Created = $this.Created
        return $response
    }
}

# The view fakes: every order recorded, every question answered from a script.
class FakeOpenView {
    [System.Collections.Generic.List[string]]$Orders
    FakeOpenView() { $this.Orders = [System.Collections.Generic.List[string]]::new() }
    [void] ShowOpening([string]$name) { $this.Orders.Add("opening $name") }
    [void] Show([object]$response) { $this.Orders.Add("report $($response.InstanceName) bare=$($response.Profile)") }
}

class FakeRestartView {
    [System.Collections.Generic.List[string]]$Orders
    [bool]$Yes = $true
    FakeRestartView() { $this.Orders = [System.Collections.Generic.List[string]]::new() }
    [void] ShowStoppingWarning([string]$name) { $this.Orders.Add("warning $name") }
    [bool] AskRestart() { $this.Orders.Add("ask"); return $this.Yes }
    [void] ShowRestarting([string]$name) { $this.Orders.Add("restarting $name") }
    [void] ShowCancelled([string]$what) { $this.Orders.Add("cancelled $what") }
    [void] Show([object]$response) { $this.Orders.Add("report $($response.InstanceName)") }
}

class FakeMigrateView {
    [System.Collections.Generic.List[string]]$Orders
    [string]$Target = ""
    FakeMigrateView() { $this.Orders = [System.Collections.Generic.List[string]]::new() }
    [string] AskTarget([string]$root) {
        $this.Orders.Add("ask root=$root")
        return $this.Target
    }
    [void] ShowSameFolder() { $this.Orders.Add("same-folder") }
    [void] ShowTargetProblem([string]$problem) { $this.Orders.Add("problem $problem") }
    [void] ShowCancelled([string]$what) { $this.Orders.Add("cancelled $what") }
    [void] ShowLead() { $this.Orders.Add("lead") }
    [void] Show([object]$response) { $this.Orders.Add("report $($response.Target) moved=$(@($response.Moved) -join ',')") }
}

class FakeWslConfigView {
    [System.Collections.Generic.List[string]]$Orders
    FakeWslConfigView() { $this.Orders = [System.Collections.Generic.List[string]]::new() }
    [void] ShowLead() { $this.Orders.Add("lead") }
    [void] Show([object]$response) { $this.Orders.Add("report $($response.Path) created=$($response.Created)") }
}


$ErrorActionPreference = "Stop"

$global:Failures = 0

# The world: the redirected profile with the root file pointing at a root of
# the suite's, one instance carrying the marker and its disk, and a marked
# folder nobody claims.
$World = Join-Path ([System.IO.Path]::GetTempPath()) ("fleet-presenters-" + [Guid]::NewGuid().ToString("N"))
$env:USERPROFILE = $World
$env:LOCALAPPDATA = Join-Path $World "LocalAppData"
$env:APPDATA = Join-Path $World "AppData"
New-Item -ItemType Directory -Path (Join-Path $env:LOCALAPPDATA "wsl-fleet") -Force | Out-Null
New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
$Root = Join-Path $World "WSL"
$Instance = "bench-agent"
$FakeFolder = Join-Path $Root $Instance
$LeftBehind = Join-Path $Root "left-behind"
Set-Content -Path (Join-Path $env:LOCALAPPDATA "wsl-fleet\root.txt") -Value $Root -Encoding ascii -NoNewline

function Reset-World {
    Remove-Item -Recurse -Force $Root -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $FakeFolder -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $FakeFolder ".wsl-fleet") -Force | Out-Null
    Set-Content -Path (Join-Path $FakeFolder "ext4.vhdx") -Value "fake-disk" -NoNewline
}
Reset-World

$instances = [InstanceRepository]::new($Root)
$archives = [ArchiveRepository]::new((Join-Path $Root "archives"))
$terminal = [TerminalRepository]::new((Join-Path $World "assets"))
$docker = [DockerRepository]::new($Root)
$config = [ConfigRepository]::new((Join-Path $World "assets"))
$fake = [FakeWsl]::new()
$fake.Folders[$Instance] = $FakeFolder
$service = [InstanceService]::new($instances, $archives, $fake, $terminal, $docker, $null, $config)
$fleet = [FakeFleet]::new($config, $fake, $instances, $archives, $service)

function New-ViewsRoot {
    return (Join-Path $PSScriptRoot "..\..\src\windows\Views")
}

$failureView = [FakeErrorView]::new()

try {
    # ---- shell (open) ------------------------------------------------------

    $openView = [FakeOpenView]::new()
    $selectView = [FakeSelectView]::new()
    $presenter = [OpenPresenter]::new($service, (New-ViewsRoot), "cli")
    $presenter.Views = @{ "Open" = $openView; "Error" = $failureView }
    $presenter.Picker.Views = @{ "SelectInstance" = $selectView }

    # 1. A given name opens straight; no Terminal profile means the bare
    # shell, and the response says so.
    $fake.Called.Clear()
    $openView.Orders.Clear()
    $result = $presenter.Run($Instance)
    Check "a given name skips the question" $selectView.Asked $false
    Check "the shell goes" "$($result.Status)/$($result.Message)" "Ok/Open : $Instance"
    Check "  ... the line before the wait" ($openView.Orders -join " | ") "opening $Instance | report $Instance bare=False"
    Check "  ... and the bare shell was the one asked" ($fake.Called -join " | ") "open-bare $Instance"

    # 2. The escape at the question is an abandonment, and an empty machine is
    # a fault.
    $fake.Distros = @($Instance)
    $selectView.Asked = $false
    $selectView.Answer = ""
    $result = $presenter.Run("")
    Check "the escape abandons" "$($result.Status)/$($result.Message)" "Ok/Open : cancelled"

    $fake.Distros = @()
    $openView.Orders.Clear()
    $result = $presenter.Run("")
    Check "an empty machine is a fault" "$($result.Status)/$($result.Message)" "Nok/Open : no instance"
    $fake.Distros = @($Instance)
    $selectView.Answer = $Instance

    # ---- restart -----------------------------------------------------------

    $restartView = [FakeRestartView]::new()
    $selectView = [FakeSelectView]::new()
    $selectView.Answer = $Instance
    $presenter = [RestartPresenter]::new($service, (New-ViewsRoot), "cli")
    $presenter.Views = @{ "Restart" = $restartView; "Error" = $failureView }
    $presenter.Picker.Views = @{ "SelectInstance" = $selectView }

    # 3. A no at the door abandons: the warning was said, nothing was touched.
    $restartView.Yes = $false
    $restartView.Orders.Clear()
    $fake.Called.Clear()
    $result = $presenter.Run("")
    Check "a no at the door abandons" "$($result.Status)/$($result.Message)" "Ok/Restart : cancelled"
    Check "  ... after the warning and the question" ($restartView.Orders -join " | ") "warning $Instance | ask | cancelled modified"
    Check "  ... and nothing was touched" ($fake.Called.Count) 0

    # 4. The yes goes: stopped, then started again - in that order.
    $restartView.Yes = $true
    $restartView.Orders.Clear()
    $fake.Called.Clear()
    $result = $presenter.Run("")
    Check "the restart goes" "$($result.Status)/$($result.Message)" "Ok/Restart : $Instance"
    Check "  ... the warning, the door, the line, the banner" `
        ($restartView.Orders -join " | ") "warning $Instance | ask | restarting $Instance | report $Instance"
    Check "  ... stopped before started" `
        (($fake.Called.IndexOf("--terminate $Instance")) -lt ($fake.Called.IndexOf("-d $Instance --exec /bin/true"))) $true

    # 5. A stop that fails names the half: the refusal reaches the error view
    # and the run is a fault.
    $fake.TerminateRefusal = "boom"
    $failureView.Orders.Clear()
    $result = $presenter.Run("")
    Check "a failed stop is a fault" "$($result.Status)" "Nok"
    Check "  ... with the half named" `
        (($failureView.Orders -join " | ") -like "error The stop did not complete - '$Instance' may still be running, and was not started again. boom") $true
    $fake.TerminateRefusal = ""

    # ---- migrate -----------------------------------------------------------

    # Nothing to carry: the fleet under the root is empty - the instantiated
    # journey (archive, unregister) is the archive bench's affair.
    $fake.Distros = @()

    $migrateView = [FakeMigrateView]::new()
    $presenter = [MigratePresenter]::new($fleet, (New-ViewsRoot), "cli")
    $presenter.Views = @{ "Migrate" = $migrateView; "Error" = $failureView }

    # 6. An empty answer cancels - with the question's own words.
    $migrateView.Target = ""
    $migrateView.Orders.Clear()
    $result = $presenter.Run("")
    Check "an empty answer cancels" "$($result.Status)/$($result.Message)" "Ok/Migrate : cancelled"
    Check "  ... the question carried the root" ($migrateView.Orders[0]) "ask root=$Root"
    Check "  ... and the cancel was said" ($migrateView.Orders -contains "cancelled moved") $true

    # 7. The working folder itself is not a refusal: it is said, and nothing
    # moves.
    $migrateView.Target = $Root
    $migrateView.Orders.Clear()
    $fake.Called.Clear()
    $result = $presenter.Run("")
    Check "the working folder is said, not refused" "$($result.Status)/$($result.Message)" "Ok/Migrate : cancelled"
    Check "  ... the line, and no cancel" ($migrateView.Orders -join " | ") "ask root=$Root | same-folder"
    Check "  ... and nothing moved" ($fake.Called.Count) 0

    # 8. A target Test-FleetTarget refuses is said with its own words, and
    # nothing moves.
    $migrateView.Target = "effef"
    $migrateView.Orders.Clear()
    $fake.Called.Clear()
    $result = $presenter.Run("")
    Check "a relative target is refused cheap" `
        ($migrateView.Orders -contains "problem 'effef' is not an absolute folder - give a full path, like 'D:\WSL'.") $true
    Check "  ... and nothing moved" ($fake.Called.Count) 0

    # 9. A good target goes: the lead, the journey (no instance to carry: the
    # archives only), the report, and the root file rewritten.
    $NewRoot = Join-Path $World "new-root"
    $migrateView.Target = $NewRoot
    $migrateView.Orders.Clear()
    $fake.Called.Clear()
    $result = $presenter.Run("")
    Check "a good target goes" "$($result.Status)/$($result.Message)" "Ok/Migrate : $NewRoot"
    Check "  ... the lead then the report" ($migrateView.Orders -join " | ") "ask root=$Root | lead | report $NewRoot moved="
    Check "  ... and the root file follows" "$(Get-Content (Join-Path $env:LOCALAPPDATA 'wsl-fleet\root.txt') -Raw)".Trim() "$NewRoot"

    # 10. A target GIVEN passes both refusals, as the window's launch does -
    # and the service's own guard still answers a target it hates.
    $GivenRoot = Join-Path $World "given-root"
    $migrateView.Orders.Clear()
    $result = $presenter.Run($GivenRoot)
    Check "a given target skips the question" (@($migrateView.Orders | Where-Object { $_ -like "ask*" }).Count) 0
    Check "  ... and goes" "$($result.Status)/$($result.Message)" "Ok/Migrate : $GivenRoot"

    $migrateView.Orders.Clear()
    $failureView.Orders.Clear()
    $result = $presenter.Run("effef")
    Check "a given relative target is the service's refusal" "$($result.Status)" "Nok"
    Check "  ... painted" (($failureView.Orders -join " | ") -like "error 'effef' is not an absolute folder*") $true

    # ---- wslconfig ---------------------------------------------------------

    $configView = [FakeWslConfigView]::new()
    $presenter = [WslConfigPresenter]::new($fleet, (New-ViewsRoot), "cli")
    $presenter.Views = @{ "WslConfig" = $configView; "Error" = $failureView }

    # 11. The lead, the call, the report - the file was born of its template.
    $fleet.Created = $true
    $fleet.Called.Clear()
    $configView.Orders.Clear()
    $result = $presenter.Run()
    Check "wslconfig goes" "$($result.Status)/$($result.Message)" "Ok/WslConfig : $($fleet.Path)"
    Check "  ... lead, call, report - created" `
        ("$($configView.Orders -join ' | ')/$($fleet.Called -join ',')") "lead | report $($fleet.Path) created=True/wslconfig"

    # 12. The file already there says its path instead.
    $fleet.Created = $false
    $configView.Orders.Clear()
    $result = $presenter.Run()
    Check "an existing file says its path" ($configView.Orders -contains "report $($fleet.Path) created=False") $true

    # 13. A service that refuses is a fault, painted by the error view.
    $fleet.Refusal = "boom"
    $failureView.Orders.Clear()
    $result = $presenter.Run()
    Check "a refused opening is a fault" "$($result.Status)/$($result.Message)" "Nok/WslConfig : boom"
    Check "  ... painted" ($failureView.Orders -join " | ") "error boom"
} finally {
    Remove-Item -Recurse -Force $World -ErrorAction SilentlyContinue
}

Write-Output ""
Write-Output ("failures: " + $global:Failures)
exit $global:Failures
