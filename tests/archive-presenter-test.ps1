# The first traversal, driven by a fake view: the archive presenter runs the
# whole conversation without a console anywhere - the view only answers what
# the presenter asks and records what it is told, and every decision (the
# cancel, the refusal, the replacing line, the Dto) is the presenter's.
#
# The service is the real one, built by hand over a world of the suite's own:
# an instance repository on a temp root, the marker and the disk a real
# instance carries, and a stand-in WslRepository - so the whole traversal
# runs anywhere, the sandbox and the runner alike, with no registry and no
# console.
#
# Usage:  pwsh -NoProfile -File tests\archive-presenter-test.ps1
using module ..\src\windows\Presenters\Instance\ArchivePresenter.psm1
using module ..\src\windows\Repositories\WslRepository.psm1
using module ..\src\windows\Entities\WslInstance.psm1
using module ..\src\windows\Repositories\InstanceRepository.psm1
using module ..\src\windows\Repositories\ArchiveRepository.psm1
using module ..\src\windows\Repositories\DockerRepository.psm1
using module ..\src\windows\Services\InstanceService.psm1

# The instance side of wsl, faked whole: the list the presenter reads, and
# the export it commands - recorded, so the Dto the presenter built shows in
# the call it produced.
class FakeWsl : WslRepository {
    [System.Collections.Generic.List[string]]$Called
    [string[]]$Distros = @()

    FakeWsl() : base([System.IO.Path]::GetTempPath()) {
        $this.Called = [System.Collections.Generic.List[string]]::new()
    }

    [WslInstance[]] GetAllDistros() {
        $found = @()
        foreach ($name in @($this.Distros)) {
            $instance = [WslInstance]::new()
            $instance.SetName($name)
            $found += $instance
        }
        return @($found)
    }

    [string[]] GetRunningNames() {
        return @()
    }

    [void] Export([string]$instanceName, [string]$tarPath, [string]$format) {
        $this.Called.Add("--export $instanceName $tarPath --format $format")
    }
}

# The view, dumb on purpose: every order recorded, every question answered
# from a script - a view that decided would hide what the presenter decides.
class FakeArchiveView {
    [System.Collections.Generic.List[string]]$Orders
    [bool]$Continue = $true

    FakeArchiveView() {
        $this.Orders = [System.Collections.Generic.List[string]]::new()
    }

    [void] ShowStopWarning([string]$name) { $this.Orders.Add("stop-warning $name") }
    [void] ShowReplacing([string]$archiveName) { $this.Orders.Add("replacing $archiveName") }
    [void] ShowBackingUp([string]$name) { $this.Orders.Add("backing-up $name") }
    [void] ShowCancelled([string]$what) { $this.Orders.Add("cancelled $what") }
    [void] Show([object]$response) { $this.Orders.Add("report $($response.InstanceName) $($response.Tar)") }
    [bool] Confirm([string]$question, [bool]$defaultNo) {
        $this.Orders.Add("confirm $question")
        return $this.Continue
    }
}

class FakeSelectView {
    [string]$Answer = ""
    [bool]$Asked = $false
    [bool]$Rang = $false
    [object[]]$Offered = @()

    [void] ShowNoInstances() { $this.Rang = $true }
    [object] AskOffered([object[]]$offered) {
        $this.Asked = $true
        $this.Offered = @($offered)
        return $this.Answer
    }
}

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

# The world: a root of the suite's own, one instance carrying the marker and
# its disk, one archive already written under the family's folder - so the
# presenter's replacing line has something to read.
$World = Join-Path ([System.IO.Path]::GetTempPath()) ("archive-presenter-" + [Guid]::NewGuid().ToString("N"))
$Root = Join-Path $World "WSL"
$Instance = "bench-agent"
$InstanceFolder = Join-Path $Root $Instance
New-Item -ItemType Directory -Path $InstanceFolder -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $InstanceFolder ".wsl-stack") -Force | Out-Null
Set-Content -Path (Join-Path $InstanceFolder "ext4.vhdx") -Value "fake-disk" -NoNewline
$SeededArchive = Join-Path $Root "archives\$($Instance)_archive"
New-Item -ItemType Directory -Path $SeededArchive -Force | Out-Null
# Un fichier valide : un dossier nu ne compte pas comme archive, et la ligne
# de l'écrasement doit avoir quelque chose à lire.
Set-Content -Path (Join-Path $SeededArchive "instance.json") -Encoding Utf8 -Value '{ "DefaultUser": "qtest" }'
Set-Content -Path (Join-Path $SeededArchive "bench-agent_archive.tar.gz") -Encoding Utf8 -Value "fake-tar"

$instances = [InstanceRepository]::new($Root)
$archives = [ArchiveRepository]::new((Join-Path $Root "archives"))
$docker = [DockerRepository]::new($Root)
$fake = [FakeWsl]::new()
$fake.Distros = @($Instance)
$service = [InstanceService]::new($instances, $archives, $fake, $null, $docker, $null, $null)

$presenter = [ArchivePresenter]::new($service, (Join-Path $PSScriptRoot "..\src\windows\Views"), "cli")
$archiveView = [FakeArchiveView]::new()
$selectView = [FakeSelectView]::new()
$presenter.Views = @{ "Archive" = $archiveView }
$presenter.Picker.Views = @{ "SelectInstance" = $selectView }

try {
    # 1. Cancel at the question: the warning comes first, the question is the
    # presenter's, the cancel is said and answered - and nothing was exported.
    $selectView.Answer = $Instance
    $archiveView.Continue = $false
    $result = $presenter.Run("")
    Check "the cancel is an Ok from the entry" "$($result.Status)/$($result.Message)" "Ok/Archive : cancelled"
    Check "the orders: the warning, the question, the cancel" ($archiveView.Orders -join " | ") "stop-warning $Instance | confirm Continue? | cancelled modified"
    Check "and nothing was exported" ($fake.Called.Count) 0

    # 2. Escape at the instance question: the presenter reads it as a cancel,
    # and the archive view was never even opened.
    $selectView.Answer = ""
    $selectView.Asked = $false
    $archiveView.Orders.Clear()
    $result = $presenter.Run("")
    Check "an escape cancels before the view exists" "$($result.Message)" "Archive : cancelled"
    Check "and the archive view was not opened" ($archiveView.Orders.Count) 0

    # 3. An empty machine: the refusal is the select view's, the fault is the
    # presenter's.
    $fake.Distros = @()
    $selectView.Rang = $false
    $result = $presenter.Run("")
    Check "an empty machine is a Nok" "$($result.Status)/$($result.Message)" "Nok/Archive : no instance"
    Check "  ... and the refusal was painted" $selectView.Rang $true

    # 4. A full run: the replacing line read from the index, the Dto built by
    # the presenter - it shows in the export - the report, and the archive's
    # own file beside the tar.
    $fake.Distros = @($Instance)
    $selectView.Answer = $Instance
    $archiveView.Continue = $true
    $archiveView.Orders.Clear()
    $fake.Called.Clear()
    $result = $presenter.Run("")
    Check "a full run is an Ok carrying the name" "$($result.Status)/$($result.Message)" "Ok/Archive : $Instance"
    Check "the orders: warning, question, replacing, backing up, report" `
        ($archiveView.Orders -join " | ") "stop-warning $Instance | confirm Continue? | replacing $($Instance)_archive | backing-up $Instance | report $Instance $($fake.Called[0] -replace '^--export \S+ (\S+) --format tar.gz$', '$1')"
    Check "and the export carried the built Dto" `
        ("$($fake.Called[0])" -match "--export $Instance .*$($Instance)_archive\.tar\.gz --format tar\.gz$") $true
    Check "  ... and the archive's own file was written" `
        (Test-Path (Join-Path $Root "archives\$($Instance)_archive\instance.json")) $true

    # 5. A target given passes straight through: the question is not asked.
    $selectView.Asked = $false
    $archiveView.Orders.Clear()
    $fake.Called.Clear()
    $result = $presenter.Run("$Instance")
    Check "a given name skips the question" $selectView.Asked $false
    Check "  ... and the traversal still runs" "$($result.Message)" "Archive : $Instance"
} finally {
    Remove-Item -Recurse -Force $World -ErrorAction SilentlyContinue
}

Write-Output ""
Write-Output ("failures: " + $Failures)
exit $Failures
