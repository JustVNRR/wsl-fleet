# The five traversals of the second lot, driven by fake views: remove,
# delete_archive, shrink (compact), restore, duplicate - each presenter runs
# its whole conversation with no console anywhere, the views record what they
# are told and replay what they are asked, and every decision (the typed
# name's -ceq, the name loop, the empty archive list, the Dto) is the
# presenter's.
#
# The service is the real one over a world of the suite's own: repositories
# on a temp root, a stand-in WslRepository recording every wsl call, and the
# redirected profile keeping Terminal's files in the temp - so the five
# traversals run anywhere, the sandbox and the runner alike.
#
# Usage:  pwsh -NoProfile -File tests\instance-presenters-test.ps1
using module ..\src\windows\Presenters\Instance\RemovePresenter.psm1
using module ..\src\windows\Presenters\Instance\DeleteArchivePresenter.psm1
using module ..\src\windows\Presenters\Instance\CompactPresenter.psm1
using module ..\src\windows\Presenters\Instance\RestorePresenter.psm1
using module ..\src\windows\Presenters\Instance\DuplicatePresenter.psm1
using module ..\src\windows\Repository\WslRepository.psm1
using module ..\src\windows\Model\WslInstance.psm1
using module ..\src\windows\Repository\InstanceRepository.psm1
using module ..\src\windows\Repository\ArchiveRepository.psm1
using module ..\src\windows\Repository\TerminalRepository.psm1
using module ..\src\windows\Repository\DockerRepository.psm1
using module ..\src\windows\Service\InstanceService.psm1

# The instance side of wsl, faked whole: every call the five gestures make is
# recorded here, so the order and the shape of what the presenters command
# are what the checks read.
class FakeWsl : WslRepository {
    [System.Collections.Generic.List[string]]$Called
    [string[]]$Distros = @()
    [string[]]$Running = @()

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

    [string[]] GetRunningNames() { return @($this.Running) }
    [void] Terminate([string]$instanceName) { $this.Called.Add("--terminate $instanceName") }
    [void] TerminateQuietly([string]$instanceName) { $this.Called.Add("--terminate $instanceName") }
    [void] Unregister([string]$instanceName) { $this.Called.Add("--unregister $instanceName") }
    [void] Start([string]$instanceName) { $this.Called.Add("-d $instanceName --exec /bin/true") }
    [void] Compact([string]$instanceName) { $this.Called.Add("--manage $instanceName --compact") }
    [void] Export([string]$instanceName, [string]$tarPath, [string]$format) { $this.Called.Add("--export $instanceName $tarPath --format $format") }
    [void] Import([string]$instanceName, [string]$folder, [string]$tarPath) {
        # Le vrai import crée le dossier : la doublure fait de même, sinon la
        # première écriture qui suit n'a nulle part où aller.
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        $this.Called.Add("--import $instanceName $folder $tarPath --version 2")
    }
}

# The four view fakes: every order recorded, every question answered from a
# script. A view that decided would hide what the presenter decides.
class FakeRemoveView {
    [System.Collections.Generic.List[string]]$Orders
    [string]$Typed = ""
    [bool]$ArchiveFirst = $false

    FakeRemoveView() { $this.Orders = [System.Collections.Generic.List[string]]::new() }

    [void] ShowDestructionGate([string]$name, [string]$lead) { $this.Orders.Add("gate $name") }
    [string] AskTypedName() { $this.Orders.Add("typed"); return $this.Typed }
    [void] ShowGateClose() { $this.Orders.Add("gate-close") }
    [void] ShowGateOpened() { $this.Orders.Add("gate-opened") }
    [void] ShowGateRefused() { $this.Orders.Add("gate-refused") }
    [void] ShowReplacingArchive([string]$name) { $this.Orders.Add("replacing $name") }
    [void] ShowRemovingSteps() { $this.Orders.Add("steps") }
    [void] Show([string]$name, [object]$response) { $this.Orders.Add("report $name") }
    [bool] Confirm([string]$question, [bool]$defaultNo) {
        $this.Orders.Add("confirm $question")
        return $this.ArchiveFirst
    }
}

class FakeCompactView {
    [System.Collections.Generic.List[string]]$Orders
    [bool]$ArchiveFirst = $false

    FakeCompactView() { $this.Orders = [System.Collections.Generic.List[string]]::new() }

    [void] ShowBeforeQuestions() { $this.Orders.Add("breath") }
    [void] ShowNoArchive() { $this.Orders.Add("no-archive") }
    [void] ShowReplacingArchive([string]$name) { $this.Orders.Add("replacing $name") }
    [void] ShowCompacting([string]$name, [bool]$archiveFirst) { $this.Orders.Add("compacting $name archive=$archiveFirst") }
    [void] Show([string]$name, [object]$response) { $this.Orders.Add("report $name restarted=$($response.Restarted)") }
    [bool] Confirm([string]$question, [bool]$defaultNo) {
        $this.Orders.Add("confirm $question")
        return $this.ArchiveFirst
    }
}

class FakeDeleteArchiveView {
    [System.Collections.Generic.List[string]]$Orders
    FakeDeleteArchiveView() { $this.Orders = [System.Collections.Generic.List[string]]::new() }
    [void] ShowNoName() { $this.Orders.Add("no-name") }
    [void] ShowDeleting([string]$name) { $this.Orders.Add("deleting $name") }
    [void] Show([string]$name, [object]$response) { $this.Orders.Add("report $name") }
}

class FakeRestoreView {
    [System.Collections.Generic.List[string]]$Orders
    [string]$Archive = ""
    [string]$Name = ""

    FakeRestoreView() { $this.Orders = [System.Collections.Generic.List[string]]::new() }

    [void] ShowNoArchives() { $this.Orders.Add("no-archives") }
    [void] ShowCancelled([string]$what) { $this.Orders.Add("cancelled $what") }
    [object] AskArchive([object[]]$archives) { $this.Orders.Add("ask-archive"); return $this.Archive }
    [void] ShowRestoring([string]$archiveName) { $this.Orders.Add("restoring $archiveName") }
    [string] AskNewName() { $this.Orders.Add("ask-name"); return $this.Name }
    [void] Show([string]$archiveName, [object]$response) { $this.Orders.Add("report $archiveName") }
}

class FakeDuplicateView {
    [System.Collections.Generic.List[string]]$Orders
    [string[]]$Answers = @()
    [int]$Asked = 0
    [bool]$Continue = $true

    FakeDuplicateView() { $this.Orders = [System.Collections.Generic.List[string]]::new() }

    [string] AskCopyName() {
        $this.Orders.Add("ask-name")
        $answer = ""
        if ($this.Asked -lt $this.Answers.Count) { $answer = $this.Answers[$this.Asked] }
        $this.Asked++
        return $answer
    }
    [void] ShowNameHint() { $this.Orders.Add("hint") }
    [void] ShowDiskWarning([string]$source) { $this.Orders.Add("warning $source") }
    [void] ShowDuplicating([string]$source, [string]$copy) { $this.Orders.Add("duplicating $source $copy") }
    [void] ShowCancelled([string]$what) { $this.Orders.Add("cancelled $what") }
    [void] Show([string]$source, [object]$response) { $this.Orders.Add("report $source $($response)") }
    [bool] Confirm([string]$question, [bool]$defaultNo) {
        $this.Orders.Add("confirm $question")
        return $this.Continue
    }
}

class FakeSelectView {
    [string]$Answer = ""
    [bool]$Asked = $false
    [bool]$Rang = $false

    [void] ShowNoInstances() { $this.Rang = $true }
    [object] AskOffered([object[]]$offered) {
        $this.Asked = $true
        return $this.Answer
    }
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

# The world: the redirected profile (Terminal's files are writes the
# traversal makes), a root of the suite's own, one instance carrying the
# marker and its disk, and one archive already written - so the replacing
# lines have something to read.
$World = Join-Path ([System.IO.Path]::GetTempPath()) ("instance-presenters-" + [Guid]::NewGuid().ToString("N"))
$env:USERPROFILE = $World
$env:LOCALAPPDATA = Join-Path $World "LocalAppData"
$env:APPDATA = Join-Path $World "AppData"
New-Item -ItemType Directory -Path $env:LOCALAPPDATA -Force | Out-Null
New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
$Root = Join-Path $World "WSL"
$Instance = "bench-agent"
$FakeFolder = Join-Path $Root $Instance

function Reset-World {
    Remove-Item -Recurse -Force $Root -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $FakeFolder -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $FakeFolder ".wsl-stack") -Force | Out-Null
    Set-Content -Path (Join-Path $FakeFolder "ext4.vhdx") -Value "fake-disk" -NoNewline
    Set-Content -Path (Join-Path $FakeFolder "periodic-file") -Value "x" -NoNewline
    $Seeded = Join-Path $Root "archives\$($Instance)_archive"
    New-Item -ItemType Directory -Path $Seeded -Force | Out-Null
    Set-Content -Path (Join-Path $Seeded "instance.json") -Encoding Utf8 -Value '{ "DefaultUser": "qtest" }'
    Set-Content -Path (Join-Path $Seeded "$($Instance)_archive.tar.gz") -Encoding Utf8 -Value "fake-tar"
}
Reset-World

$instances = [InstanceRepository]::new($Root)
$archives = [ArchiveRepository]::new((Join-Path $Root "archives"))
$terminal = [TerminalRepository]::new($Root)
$docker = [DockerRepository]::new($Root)
$fake = [FakeWsl]::new()
$fake.Distros = @($Instance)
$service = [InstanceService]::new($instances, $archives, $fake, $terminal, $docker, $null, $null)

function New-ViewsRoot {
    return (Join-Path $PSScriptRoot "..\src\windows\Views")
}

try {
    # ---- remove ------------------------------------------------------------

    $removeView = [FakeRemoveView]::new()
    $selectView = [FakeSelectView]::new()
    $selectView.Answer = $Instance
    $presenter = [RemovePresenter]::new($service, (New-ViewsRoot), "cli")
    $presenter.Views = @{ "Remove" = $removeView }
    $presenter.Picker.Views = @{ "SelectInstance" = $selectView }

    # 1. The gate: a name that is not the exact one is refused, nothing is
    # touched - and the case is the point (-cne).
    $fake.Called.Clear()
    $removeView.Typed = $Instance.ToUpper()
    $result = $presenter.Run("")
    Check "remove refuses a case-only name" "$($result.Status)/$($result.Message)" "Ok/Remove : cancelled"
    Check "  ... the gate said so, before the question" ($removeView.Orders -join " | ") "gate $Instance | typed | gate-close | gate-refused"
    Check "  ... and nothing was touched" ($fake.Called.Count) 0
    Check "  ... and the folder stays" (Test-Path $FakeFolder) $true

    # 2. The exact name passes: the last copy question, the steps, the call -
    # stop and unregister, in that order - and the report.
    Reset-World
    $removeView.Orders.Clear()
    $removeView.Typed = $Instance
    $removeView.ArchiveFirst = $false
    $fake.Called.Clear()
    $result = $presenter.Run("")
    Check "remove with the exact name goes" "$($result.Status)/$($result.Message)" "Ok/Remove : $Instance"
    Check "  ... the breath after the gate" ($removeView.Orders -contains "gate-opened") $true
    Check "  ... stop before unregister" (($fake.Called.IndexOf("--terminate $Instance")) -lt ($fake.Called.IndexOf("--unregister $Instance"))) $true
    Check "  ... and the report" ($removeView.Orders -contains "report $Instance") $true

    # 3. Archive first: the export comes before anything is destroyed.
    Reset-World
    $removeView.Orders.Clear()
    $removeView.Typed = $Instance
    $removeView.ArchiveFirst = $true
    $fake.Called.Clear()
    $result = $presenter.Run("")
    $exportAt = -1
    $unregisterAt = -1
    for ($i = 0; $i -lt $fake.Called.Count; $i++) {
        if ("$($fake.Called[$i])" -like "--export*") { $exportAt = $i }
        if ("$($fake.Called[$i])" -like "--unregister*") { $unregisterAt = $i }
    }
    Check "remove with a copy exports first" ($exportAt -ge 0 -and $unregisterAt -gt $exportAt) $true
    Check "  ... and the replacing line was read from the index" ($removeView.Orders -contains "replacing $Instance") $true

    # ---- delete_archive ----------------------------------------------------

    Reset-World
    $deleteView = [FakeDeleteArchiveView]::new()
    $presenter = [DeleteArchivePresenter]::new($service, (New-ViewsRoot), "cli")
    $presenter.Views = @{ "DeleteArchive" = $deleteView }

    $result = $presenter.Run("")
    Check "delete_archive without a name is a fault" "$($result.Status)/$($result.Message)" "Nok/DeleteArchive : no name"
    Check "  ... and the refusal was painted" ($deleteView.Orders -contains "no-name") $true

    $result = $presenter.Run("$($Instance)_archive")
    Check "delete_archive with a name goes" "$($result.Status)/$($result.Message)" "Ok/DeleteArchive : $($Instance)_archive"
    Check "  ... and the archive is gone for good" (Test-Path (Join-Path $Root "archives\$($Instance)_archive")) $false

    # ---- shrink (compact) --------------------------------------------------

    Reset-World
    $compactView = [FakeCompactView]::new()
    $selectView = [FakeSelectView]::new()
    $selectView.Answer = $Instance
    $presenter = [CompactPresenter]::new($service, (New-ViewsRoot), "cli")
    $presenter.Views = @{ "Compact" = $compactView }
    $presenter.Picker.Views = @{ "SelectInstance" = $selectView }

    # 4. No copy, stopped: one compact, nothing started, no replacing line.
    $compactView.ArchiveFirst = $false
    $removeView.Typed = $Instance
    $fake.Running = @()
    $fake.Called.Clear()
    $result = $presenter.Run("")
    Check "shrink with no copy compacts and nothing else" "$($result.Status)/$($result.Message)" "Ok/Compact : $Instance"
    Check "  ... the no-archive line, then the avis" (($compactView.Orders -join " | ") -like "breath | confirm Archive it first? | no-archive | compacting $Instance archive=False | report $Instance restarted=False") $true
    Check "  ... one compact, and no start" (($fake.Called -join " | ")) "--manage $Instance --compact"

    # 5. A running instance comes back, and the line says so.
    Reset-World
    $fake.Running = @($Instance)
    $fake.Called.Clear()
    $compactView.Orders.Clear()
    $result = $presenter.Run("")
    Check "a running one is started again, said" ($compactView.Orders -contains "report $Instance restarted=True") $true
    Check "  ... the compact before the start" (($fake.Called.IndexOf("--manage $Instance --compact")) -lt ($fake.Called.IndexOf("-d $Instance --exec /bin/true"))) $true

    # ---- restore -----------------------------------------------------------

    Reset-World
    $restoreView = [FakeRestoreView]::new()
    $presenter = [RestorePresenter]::new($service, (New-ViewsRoot), "cli")
    $presenter.Views = @{ "Restore" = $restoreView }

    # 6. An empty machine, no name given: the refusal is a fault.
    Remove-Item -Recurse -Force (Join-Path $Root "archives") -ErrorAction SilentlyContinue
    $result = $presenter.Run("")
    Check "restore with no archives is a fault" "$($result.Status)/$($result.Message)" "Nok/Restore : there are no archives"
    Check "  ... and the refusal was painted" ($restoreView.Orders -contains "no-archives") $true

    # 7. A pick and a name: the import goes in at version 2, the marker says
    # restore, and the report names the archive.
    Reset-World
    $restoreView.Orders.Clear()
    $restoreView.Archive = "$($Instance)_archive"
    $restoreView.Name = "restored-one"
    $fake.Called.Clear()
    $result = $presenter.Run("")
    Check "restore goes with a pick and a name" "$($result.Status)/$($result.Message)" "Ok/Restore : restored-one"
    Check "  ... the import at version 2" (($fake.Called -join " | ") -like "--import restored-one * --version 2") $true
    $marker = Get-Content -Raw (Join-Path (Join-Path $Root "restored-one") ".wsl-stack") | ConvertFrom-Json
    Check "  ... and the marker says restore" "$($marker.by)" "restore"

    # 8. An empty name cancels, before anything is imported.
    Reset-World
    $restoreView.Orders.Clear()
    $restoreView.Archive = "$($Instance)_archive"
    $restoreView.Name = ""
    $fake.Called.Clear()
    $result = $presenter.Run("")
    Check "an empty name cancels the restore" "$($result.Status)/$($result.Message)" "Ok/Restore : cancelled"
    Check "  ... and nothing was imported" ($fake.Called.Count) 0

    # ---- duplicate ---------------------------------------------------------

    Reset-World
    $duplicateView = [FakeDuplicateView]::new()
    $selectView = [FakeSelectView]::new()
    $selectView.Answer = $Instance
    $presenter = [DuplicatePresenter]::new($service, (New-ViewsRoot), "cli")
    $presenter.Views = @{ "Duplicate" = $duplicateView }
    $presenter.Picker.Views = @{ "SelectInstance" = $selectView }

    # 9. The name loop: a form refused comes back with the hint; the empty
    # cancels.
    $duplicateView.Answers = @("not a name!", "")
    $result = $presenter.Run("")
    Check "a refused copy name is asked again, the empty cancels" "$($result.Status)/$($result.Message)" "Ok/Duplicate : cancelled"
    Check "  ... the hint was shown between the two" (($duplicateView.Orders -join " | ") -like "ask-name | hint | ask-name | cancelled created") $true

    # 10. A good name, the disk avis, the leads, the call: export to the
    # temporary tar, import at version 2, the marker - and the report.
    Reset-World
    $duplicateView.Orders.Clear()
    $duplicateView.Answers = @("copied-one")
    $duplicateView.Asked = 0
    $duplicateView.Continue = $true
    $fake.Called.Clear()
    $result = $presenter.Run("")
    Check "duplicate goes with a good name" "$($result.Status)/$($result.Message)" "Ok/Duplicate : copied-one"
    Check "  ... export then import, version 2" `
        ("$(($fake.Called | Where-Object { $_ -like '--export*' }).Count)/$(($fake.Called | Where-Object { $_ -like '--import copied-one * --version 2' }).Count)") "1/1"
    $marker = Get-Content -Raw (Join-Path (Join-Path $Root "copied-one") ".wsl-stack") | ConvertFrom-Json
    Check "  ... and the marker says duplicate" "$($marker.by)" "duplicate"

    # 11. The avis answered no: nothing runs.
    Reset-World
    $duplicateView.Orders.Clear()
    $duplicateView.Answers = @("copied-two")
    $duplicateView.Asked = 0
    $duplicateView.Continue = $false
    $fake.Called.Clear()
    $result = $presenter.Run("")
    Check "answered no, the copy is cancelled" "$($result.Status)/$($result.Message)" "Ok/Duplicate : cancelled"
    Check "  ... and nothing was exported" ($fake.Called.Count) 0
} finally {
    Remove-Item -Recurse -Force $World -ErrorAction SilentlyContinue
}

Write-Output ""
Write-Output ("failures: " + $Failures)
exit $Failures
