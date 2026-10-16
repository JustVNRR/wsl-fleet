# The Docker Desktop gestures, driven by fake views: register and unregister,
# each presenter runs its whole conversation with no console anywhere - the
# candidates filtered from the rows' state (an unreadable one is not an
# offer), the pick, the two questions, and the Dto. The service is the real
# one over a world of the suite's own, with a stand-in Docker Desktop whose
# settings are a table: every write, every restart and every start is
# recorded in the order the service makes it.
#
# Usage:  pwsh -NoProfile -File tests\docker-presenters-test.ps1
using module ..\src\windows\Presenters\Instance\RegisterDockerPresenter.psm1
using module ..\src\windows\Presenters\Instance\UnregisterDockerPresenter.psm1
using module ..\src\windows\Repositories\WslRepository.psm1
using module ..\src\windows\Entities\WslInstance.psm1
using module ..\src\windows\Repositories\InstanceRepository.psm1
using module ..\src\windows\Repositories\ArchiveRepository.psm1
using module ..\src\windows\Repositories\TerminalRepository.psm1
using module ..\src\windows\Repositories\DockerRepository.psm1
using module ..\src\windows\Services\InstanceService.psm1

# wsl, faked to the little the index needs: the distro names - the rest of
# the world lives in the folder each name points at.
class FakeWsl : WslRepository {
    [string[]]$Distros = @()
    FakeWsl() : base([System.IO.Path]::GetTempPath()) { }
    [WslInstance[]] GetAllDistros() {
        $found = @()
        foreach ($name in @($this.Distros)) {
            $instance = [WslInstance]::new()
            $instance.SetName($name)
            $found += $instance
        }
        return @($found)
    }
}

class FakeDocker : DockerRepository {
    [System.Collections.Generic.List[string]]$Called
    [hashtable]$States = @{}
    [bool]$Readable = $true
    [bool]$Running = $true
    [bool]$RestartOk = $true
    [bool]$StartOk = $true

    FakeDocker() : base([System.IO.Path]::GetTempPath()) {
        $this.Called = [System.Collections.Generic.List[string]]::new()
    }

    [object] GetDesktopNames() {
        if (-not $this.Readable) { return $null }
        $names = @()
        foreach ($key in @($this.States.Keys)) {
            if ("$($this.States[$key])" -eq "yes") { $names += "$key" }
        }
        return @($names)
    }
    [string] GetDesktopState([string]$instanceName) {
        if (-not $this.Readable) { return "unknown" }
        if ($this.States.ContainsKey($instanceName)) { return "$($this.States[$instanceName])" }
        return "no"
    }
    [void] SetDesktopState([string]$instanceName) { $this.Called.Add("set $instanceName"); $this.States[$instanceName] = "yes" }
    [void] RemoveDesktopState([string]$instanceName) { $this.Called.Add("remove $instanceName"); $this.States[$instanceName] = "no" }
    [bool] RestartDesktop() { $this.Called.Add("restart"); return $this.RestartOk }
    [bool] StartDesktop() { $this.Called.Add("start"); return $this.StartOk }
    [bool] TestRunning() { $this.Called.Add("running"); return $this.Running }
}

class FakeDockerView {
    [System.Collections.Generic.List[string]]$Orders
    [bool]$RegisterAnswer = $true
    [bool]$RestartAnswer = $true
    [bool]$UnregisterAnswer = $true
    FakeDockerView() { $this.Orders = [System.Collections.Generic.List[string]]::new() }
    [void] ShowNoCandidates() { $this.Orders.Add("no-candidates") }
    [void] ShowSettingsUnreadable() { $this.Orders.Add("settings-unreadable") }
    [void] ShowAlreadyRegistered([string]$name) { $this.Orders.Add("already-registered $name") }
    [void] ShowNotRegistered([string]$name) { $this.Orders.Add("not-registered $name") }
    [void] ShowCancelled([string]$what) { $this.Orders.Add("cancelled $what") }
    [bool] AskRegister([string]$name) { $this.Orders.Add("ask-register $name"); return $this.RegisterAnswer }
    [bool] AskUnregister([string]$name) { $this.Orders.Add("ask-unregister $name"); return $this.UnregisterAnswer }
    [bool] AskRestartDocker() { $this.Orders.Add("ask-restart"); return $this.RestartAnswer }
    [void] Show([object]$response) { $this.Orders.Add("report $($response.InstanceName) $($response.Restart)") }
}

class FakeSelectView {
    [string]$Answer = ""
    [string]$Saw = ""
    [void] ShowNoInstances() { $this.Saw = "none" }
    [object] AskOffered([object[]]$offered) {
        $this.Saw = (@($offered) | ForEach-Object { "$($_.Name)" }) -join ","
        return $this.Answer
    }
}

class FakeErrorView {
    [System.Collections.Generic.List[string]]$Orders
    FakeErrorView() { $this.Orders = [System.Collections.Generic.List[string]]::new() }
    [void] Show([string]$failure) { $this.Orders.Add("error $failure") }
}

$ErrorActionPreference = "Stop"

$Failures = 0
function Check {
    param([string]$Name, $Got, $Expected)
    if ("$Got" -eq "$Expected") {
        Write-Output "OK   $Name"
    } else {
        Write-Output "FAIL $Name : expected '$Expected', got '$Got'"
        $script:Failures++
    }
}

# The world: the redirected profile, a root of the suite's own, three live
# instances carrying their marker and their disk - alpha unregistered, beta
# carried, gamma unreadable.
$World = Join-Path ([System.IO.Path]::GetTempPath()) ("docker-presenters-" + [Guid]::NewGuid().ToString("N"))
$env:USERPROFILE = $World
$env:LOCALAPPDATA = Join-Path $World "LocalAppData"
$env:APPDATA = Join-Path $World "AppData"
New-Item -ItemType Directory -Path $env:LOCALAPPDATA -Force | Out-Null
New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
$Root = Join-Path $World "WSL"
foreach ($name in @("alpha", "beta", "gamma")) {
    $folder = Join-Path $Root $name
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $folder ".wsl-stack") -Force | Out-Null
    Set-Content -Path (Join-Path $folder "ext4.vhdx") -Value "fake-disk" -NoNewline
}

$instances = [InstanceRepository]::new($Root)
$archives = [ArchiveRepository]::new((Join-Path $Root "archives"))
$terminal = [TerminalRepository]::new($Root)
$docker = [FakeDocker]::new()
$fake = [FakeWsl]::new()
$fake.Distros = @("alpha", "beta", "gamma")
$service = [InstanceService]::new($instances, $archives, $fake, $terminal, $docker, $null, $null)

function New-ViewsRoot {
    return (Join-Path $PSScriptRoot "..\src\windows\Views")
}

# The standard table, posed before every scene: a fresh world of states, a
# fresh trail, a running Docker Desktop.
function Reset-Docker {
    $docker.States = @{ alpha = "no"; beta = "yes"; gamma = "unknown" }
    $docker.Readable = $true
    $docker.Running = $true
    $docker.RestartOk = $true
    $docker.StartOk = $true
    $docker.Called.Clear()
}
Reset-Docker

$view = [FakeDockerView]::new()
$select = [FakeSelectView]::new()
$failure = [FakeErrorView]::new()

$register = [RegisterDockerPresenter]::new($service, (New-ViewsRoot), "cli")
$register.Views = @{ "RegisterDocker" = $view; "Error" = $failure }
$register.Picker.Views = @{ "SelectInstance" = $select }

$unregister = [UnregisterDockerPresenter]::new($service, (New-ViewsRoot), "cli")
$unregister.Views = @{ "UnregisterDocker" = $view; "Error" = $failure }
$unregister.Picker.Views = @{ "SelectInstance" = $select }

try {
    # ---- register ----------------------------------------------------------

    # 1. The candidates are the live rows Docker Desktop does not carry, and
    # the menu shows them even when there are two.
    Reset-Docker
    $select.Answer = "alpha"
    $view.Orders.Clear()
    $result = $register.Run("")
    Check "the register offer is the unregistered rows alone" $select.Saw "alpha,gamma"
    Check "the questions in order, the report at the end" ($view.Orders -join " | ") "ask-register alpha | ask-restart | report alpha restarted"
    Check "the write and the restart, in that order" ($docker.Called -join " | ") "set alpha | running | restart"
    Check "  ... and the gesture is an Ok" "$($result.Status)/$($result.Message)" "Ok/RegisterDocker : alpha"

    # 2. The restart declined: the name is written, and nothing is restarted.
    Reset-Docker
    $view.RestartAnswer = $false
    $view.Orders.Clear()
    $result = $register.Run("alpha")
    Check "a declined restart writes and stops" ($docker.Called -join " | ") "set alpha"
    Check "  ... the report says when it applies" ($view.Orders -join " | ") "ask-register alpha | ask-restart | report alpha "
    $view.RestartAnswer = $true

    # 3. Docker Desktop off, the restart asked: it is started, not restarted.
    Reset-Docker
    $docker.Running = $false
    $view.Orders.Clear()
    $result = $register.Run("alpha")
    Check "a stopped Docker Desktop is started" ($docker.Called -join " | ") "set alpha | running | start"
    Check "  ... and the report says so" ($view.Orders -join " | ") "ask-register alpha | ask-restart | report alpha started"

    # 4. The confirmation declined: nothing is written.
    Reset-Docker
    $view.RegisterAnswer = $false
    $view.Orders.Clear()
    $result = $register.Run("alpha")
    Check "a declined register writes nothing" ($docker.Called -join " | ") ""
    Check "  ... and says the cancellation" ($view.Orders -join " | ") "ask-register alpha | cancelled modified"
    $view.RegisterAnswer = $true

    # 5. A name given on the command line is checked first: carried, then
    # unreadable, then not one of ours.
    Reset-Docker
    $view.Orders.Clear(); $failure.Orders.Clear()
    $result = $register.Run("beta")
    Check "a carried name is not registered again" ($view.Orders -join " | ") "already-registered beta"
    Check "  ... the refusal is a fault" "$($result.Status)" "Nok"
    $docker.Readable = $false
    $view.Orders.Clear()
    $result = $register.Run("alpha")
    Check "an unreadable settings file stops the gesture" ($view.Orders -join " | ") "settings-unreadable"
    $docker.Readable = $true
    $failure.Orders.Clear()
    $result = $register.Run("zzz")
    Check "a name that is not ours is said" ($failure.Orders -join " | ") "error 'zzz' is not an instance of this machine."

    # 6. Nothing to register: every row carried - then every row unreadable.
    Reset-Docker
    $docker.States = @{ alpha = "yes"; beta = "yes"; gamma = "yes" }
    $view.Orders.Clear()
    $result = $register.Run("")
    Check "nothing unregistered: the empty list is said" ($view.Orders -join " | ") "no-candidates"
    $docker.Readable = $false
    $view.Orders.Clear()
    $result = $register.Run("")
    Check "settings unreadable: the empty list is blamed on them" ($view.Orders -join " | ") "settings-unreadable"

    # ---- unregister --------------------------------------------------------

    # 7. The mirrored traversal: the candidates are the carried ones alone.
    Reset-Docker
    $select.Answer = "beta"
    $view.Orders.Clear()
    $result = $unregister.Run("")
    Check "the unregister offer is the carried row alone" $select.Saw "beta"
    Check "the questions in order, the report at the end" ($view.Orders -join " | ") "ask-unregister beta | ask-restart | report beta restarted"
    Check "the removal and the restart, in that order" ($docker.Called -join " | ") "remove beta | running | restart"
    Check "  ... and the gesture is an Ok" "$($result.Status)/$($result.Message)" "Ok/UnregisterDocker : beta"

    # 8. A name that carries nothing, and an empty offer.
    Reset-Docker
    $view.Orders.Clear()
    $result = $unregister.Run("alpha")
    Check "an uncarried name is not taken out" ($view.Orders -join " | ") "not-registered alpha"
    $docker.States = @{ alpha = "no"; beta = "no"; gamma = "no" }
    $view.Orders.Clear()
    $result = $unregister.Run("")
    Check "nothing carried: the empty list is said" ($view.Orders -join " | ") "no-candidates"

    # 9. A restart Docker Desktop will not do: the name is written all the
    # same, and the report says it applies at the next start.
    Reset-Docker
    $docker.RestartOk = $false
    $view.Orders.Clear()
    $result = $unregister.Run("beta")
    Check "a restart that fails is not a fault" "$($result.Status)" "Ok"
    Check "  ... the report says when it applies" ($view.Orders -join " | ") "ask-unregister beta | ask-restart | report beta pending"
} finally {
    Remove-Item -Recurse -Force $World -ErrorAction SilentlyContinue
}

Write-Output ""
Write-Output ("failures: " + $Failures)
exit $Failures
