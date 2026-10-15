# The birth's traversal of the fourth lot, driven by a fake view: build runs
# its whole questionnaire with no console anywhere - the view records what it
# is told and replays what it is asked, and every decision (the name's shape,
# the registry's re-ask, the family's filter and pre-tick, the proposed
# account, the Dto, the Docker gate) is the presenter's.
#
# The service is the real one over a world of the suite's own: repositories on
# a temp root, a stand-in WslRepository and DockerRepository (the gates), the
# recipe folders read from assets of the suite's, and the packs catalogue from
# a packs folder of its own - so the traversal runs anywhere, the sandbox and
# the runner alike.
#
# Usage:  pwsh -NoProfile -File tests\build-presenter-test.ps1
using module ..\src\windows\Presenters\Instance\BuildPresenter.psm1
using module ..\src\windows\Repository\WslRepository.psm1
using module ..\src\windows\Repository\InstanceRepository.psm1
using module ..\src\windows\Repository\ArchiveRepository.psm1
using module ..\src\windows\Repository\TerminalRepository.psm1
using module ..\src\windows\Repository\DockerRepository.psm1
using module ..\src\windows\Repository\PackCatalogRepository.psm1
using module ..\src\windows\Repository\ConfigRepository.psm1
using module ..\src\windows\Dto\InstanceDto.psm1
using module ..\src\windows\Model\WslInstance.psm1
using module ..\src\windows\Service\InstanceService.psm1

# The instance side of wsl, faked whole - the distros the duplicate-name check
# reads, and the pack moves the birth would make (unreached here: the scenes
# stop at the builder).
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
}

# Docker, faked at its seams: the two gates, the registry's door, the
# storehouse, and the builder - which refuses, so the traversal stops there.
class FakeDocker : DockerRepository {
    [System.Collections.Generic.List[string]]$Called
    [bool]$Responsive = $true
    [hashtable]$RegistryVerdict = @{ Ok = $false; Why = "no such image or tag on Docker Hub" }
    [string]$BuilderRefusal = "the builder refused"
    [object[]]$SavedImages = @()

    FakeDocker() : base([System.IO.Path]::GetTempPath()) {
        $this.Called = [System.Collections.Generic.List[string]]::new()
    }

    [bool] TestRunning() {
        $this.Called.Add("running")
        return $this.Responsive
    }

    [bool] StartDesktop() {
        $this.Called.Add("desktop")
        return $false
    }

    [hashtable] TestRegistryImage([string]$reference) {
        $this.Called.Add("registry $reference")
        return $this.RegistryVerdict
    }

    [object[]] GetAllSavedImages() { return @($this.SavedImages) }

    [void] Build([string]$tag, [string]$dockerfile, [string]$context) {
        $this.Called.Add("build $tag $dockerfile $context")
        if ($this.BuilderRefusal) { throw $this.BuilderRefusal }
    }
}

# The view fake: every order recorded, every question answered from a script.
class FakeBuildView {
    [System.Collections.Generic.List[string]]$Orders
    [string[]]$NameAnswers = @()
    [int]$NameAt = 0
    [string[]]$RoadAnswers = @()
    [int]$RoadAt = 0
    [string[]]$RefAnswers = @()
    [int]$RefAt = 0
    [string[]]$SourcePicks = @()
    [int]$SourceAt = 0
    [string[]]$PackPicks = @()
    [string[]]$BootPicks = @()
    [int]$BootAt = 0
    [bool]$RunOnboarding = $true
    [string[]]$UserAnswers = @()
    [int]$UserAt = 0
    [bool]$Keep = $false
    [bool]$Register = $false
    [string]$PackOffer = ""
    [string]$PackChecked = ""
    [string]$PackNote = ""
    [string]$LastUserPrompt = ""

    FakeBuildView() { $this.Orders = [System.Collections.Generic.List[string]]::new() }

    hidden [string] Next([string[]]$answers, [int]$at) {
        if ($at -lt $answers.Count) { return "$($answers[$at])" }
        return ""
    }

    [void] ClearScreen() { $this.Orders.Add("clear") }
    [void] ShowNameHint() { $this.Orders.Add("hint-name") }
    [void] ShowUserHint() { $this.Orders.Add("hint-user") }
    [void] ShowBeforeAccount() { $this.Orders.Add("account-breath") }
    [void] ShowNoPackChosen() { $this.Orders.Add("no-pack") }
    [void] ShowNoOnboarding() { $this.Orders.Add("no-onboarding") }
    [void] ShowCancelled([string]$what) { $this.Orders.Add("cancelled $what") }
    [void] ShowUnknownRegistry([string]$reference, [string]$why) { $this.Orders.Add("unknown $reference / $why") }
    [void] ShowAbort([string[]]$lines) { $this.Orders.Add("abort $($lines -join ' / ')") }
    [void] Show([string]$name, [object]$response) { $this.Orders.Add("report $name $($response.Status)") }

    [string] AskInstanceName([string]$question) {
        $answer = $this.Next($this.NameAnswers, $this.NameAt)
        $this.NameAt++
        $this.Orders.Add("name")
        return $answer
    }

    [object] AskRoad() {
        $answer = $this.Next($this.RoadAnswers, $this.RoadAt)
        $this.RoadAt++
        $this.Orders.Add("road $answer")
        if (-not $answer) { return "" }
        $type = switch ($answer) {
            "dockerfile" { [WslBuildType]::Dockerfile }
            "image"      { [WslBuildType]::Image }
            "registry"   { [WslBuildType]::Registry }
        }
        $label = if ($answer -eq "image") { "Docker image" } elseif ($answer -eq "registry") { "Docker registry" } else { "Dockerfile" }
        return [PSCustomObject]@{ Type = $type; Label = $label }
    }

    [string] AskRegistryReference([string]$question) {
        $answer = $this.Next($this.RefAnswers, $this.RefAt)
        $this.RefAt++
        $this.Orders.Add("ref $answer")
        return $answer
    }

    [object] AskSource([string]$label, [object[]]$rows) {
        $answer = $this.Next($this.SourcePicks, $this.SourceAt)
        $this.SourceAt++
        $this.Orders.Add("source $label")
        foreach ($row in @($rows)) {
            if ("$($row.Name)" -like "$answer*") { return $row }
        }
        return ""
    }

    [object[]] AskPacks([string]$name, [object[]]$offered, [int[]]$checked, [string]$note) {
        $this.PackOffer = "$($offered.Name -join ',')"
        $this.PackChecked = "$($checked -join ',')"
        $this.PackNote = $note
        $this.Orders.Add("packs")
        if ($this.PackPicks -contains "ESCAPE") { return $null }
        $chosen = @()
        foreach ($row in @($offered)) {
            if ($this.PackPicks -contains "$($row.Name)") { $chosen += $row }
        }
        return $chosen
    }

    [bool] AskRunOnboarding() {
        $this.Orders.Add("onboarding-run")
        return $this.RunOnboarding
    }

    [object] AskOnboarding([object[]]$boots) {
        $answer = $this.Next($this.BootPicks, $this.BootAt)
        $this.BootAt++
        $this.Orders.Add("onboarding")
        foreach ($row in @($boots)) {
            if ("$($row.Name)" -like "$answer*") { return $row }
        }
        return ""
    }

    [string] AskUserName([string]$prompt) {
        $this.LastUserPrompt = $prompt
        $answer = $this.Next($this.UserAnswers, $this.UserAt)
        $this.UserAt++
        $this.Orders.Add("user")
        return $answer
    }

    [bool] AskKeepImage() {
        $this.Orders.Add("keep")
        return $this.Keep
    }

    [bool] AskRegisterDocker([string]$name) {
        $this.Orders.Add("register")
        return $this.Register
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

# The world: the redirected profile, a root of the suite's own, recipe folders
# staged under assets of the suite's (two Dockerfiles of the Debian family -
# the list question needs two rows - and one onboarding), and a packs folder
# whose catalogue carries the shell pack the birth pre-ticks.
$World = Join-Path ([System.IO.Path]::GetTempPath()) ("build-presenter-" + [Guid]::NewGuid().ToString("N"))
$env:USERPROFILE = $World
$env:LOCALAPPDATA = Join-Path $World "LocalAppData"
$env:APPDATA = Join-Path $World "AppData"
$env:USERNAME = "Jean.Dupont"
New-Item -ItemType Directory -Path $env:LOCALAPPDATA -Force | Out-Null
New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
$Root = Join-Path $World "WSL"
New-Item -ItemType Directory -Path $Root -Force | Out-Null

$Assets = Join-Path $World "assets"
foreach ($slot in @("bench-a", "bench-b")) {
    New-Item -ItemType Directory -Path (Join-Path $Assets "dockerfiles\$slot") -Force | Out-Null
    Set-Content -Path (Join-Path $Assets "dockerfiles\$slot\Dockerfile") -Value "FROM debian:bookworm-slim"
}
New-Item -ItemType Directory -Path (Join-Path $Assets "onboardings\bench-boot") -Force | Out-Null
Set-Content -Path (Join-Path $Assets "onboardings\bench-boot\onboarding.sh") -Value "#!/bin/sh"

$PacksRoot = Join-Path $World "packs"
function Add-Pack {
    param([string]$Name, [string]$Description, [string]$Requires, [string]$Visible)
    $Folder = Join-Path $PacksRoot $Name
    New-Item -ItemType Directory -Path $Folder -Force | Out-Null
    $Conf = @("PACK_DESCRIPTION := $Description")
    if ($Requires) { $Conf += "PACK_REQUIRES := $Requires" }
    if ($Visible) { $Conf += "PACK_VISIBLE := $Visible" }
    Set-Content -Path (Join-Path $Folder "pack.conf") -Value $Conf
}
Add-Pack -Name "base"        -Description "The base layer"
Add-Pack -Name "extra"       -Description "An extra pack" -Requires "base"
Add-Pack -Name "oh_my_shell" -Description "The shell"
Add-Pack -Name "solo"        -Description "A lone pack"
Add-Pack -Name "hidden"      -Description "An invisible pack" -Visible "no"

$instances = [InstanceRepository]::new($Root)
$archives = [ArchiveRepository]::new((Join-Path $Root "archives"))
$terminal = [TerminalRepository]::new($Assets)
$docker = [FakeDocker]::new()
$packs = [PackCatalogRepository]::new($PacksRoot)
$config = [ConfigRepository]::new($Assets)
$fake = [FakeWsl]::new()
$service = [InstanceService]::new($instances, $archives, $fake, $terminal, $docker, $packs, $config)

# Un monde nu : des assets sans recette ni onboarding - les deux refus du
# choix de la source s'y disent.
$BareAssets = Join-Path $World "bare-assets"
New-Item -ItemType Directory -Path $BareAssets -Force | Out-Null
$BareService = [InstanceService]::new($instances, $archives, $fake, $terminal, $docker, $packs, [ConfigRepository]::new($BareAssets))

function New-ViewsRoot {
    return (Join-Path $PSScriptRoot "..\src\windows\Views")
}

# Les réponses d'une scène tiennent dans les compteurs de la vue : chaque
# scène les remet à zéro avant de rejouer.
function Reset-BuildAnswers {
    param([FakeBuildView]$View)
    $View.NameAt = 0; $View.RoadAt = 0; $View.RefAt = 0
    $View.SourceAt = 0; $View.BootAt = 0; $View.UserAt = 0
}

$view = [FakeBuildView]::new()
$failureView = [FakeErrorView]::new()
$presenter = [BuildPresenter]::new($service, (New-ViewsRoot), "cli")
$presenter.Views = @{ "Build" = $view; "Error" = $failureView }

try {
    # 1. An empty name cancels: the view says so, nothing else is asked.
    $view.NameAnswers = @("")
    $view.Orders.Clear()
    $result = $presenter.Run()
    Check "an empty name cancels" "$($result.Status)/$($result.Message)" "Ok/Build : cancelled"
    Check "  ... said once, after the breath" ($view.Orders -join " | ") "clear | name | cancelled modified"

    # 2. A refused shape comes back to the question, and the escape at the
    # road cancels.
    $view.NameAnswers = @("bad name", "bench-build")
    $view.RoadAnswers = @("")
    Reset-BuildAnswers $view
    $view.Orders.Clear()
    $result = $presenter.Run()
    Check "a refused name is hinted, then taken" ($view.Orders -join " | ") "clear | name | hint-name | name | clear | road  | cancelled modified"
    Check "  ... and the road's escape cancels" "$($result.Status)/$($result.Message)" "Ok/Build : cancelled"

    # 3. The registry road: an unknown name comes back with the door's own
    # words, and an empty answer cancels.
    $view.NameAnswers = @("bench-build")
    $view.RoadAnswers = @("registry")
    $view.RefAnswers = @("zrgzrg", "")
    Reset-BuildAnswers $view
    $view.Orders.Clear()
    $docker.Called.Clear()
    $result = $presenter.Run()
    Check "an unknown registry name is refused" ($view.Orders -contains "unknown zrgzrg / no such image or tag on Docker Hub") $true
    Check "  ... and the empty answer cancels" "$($result.Status)/$($result.Message)" "Ok/Build : cancelled"
    Check "  ... the empty answer cancelled before the door" (@($docker.Called | Where-Object { $_ -like "registry*" }).Count) 1
    Check "  ... and nothing built" (@($docker.Called | Where-Object { $_ -like "build*" }).Count) 0

    # 4. A known reference goes on: the packs are offered whole (a registry
    # reference carries no family - the note says so), and the Docker gate
    # refuses before anything is made.
    $view.RefAnswers = @("alpine:latest")
    Reset-BuildAnswers $view
    $view.PackPicks = @("base")
    $view.BootPicks = @("bench-boot")
    $view.RunOnboarding = $false
    $view.UserAnswers = @()
    $view.UserAt = 0
    $view.Keep = $false
    $view.Register = $false
    $view.Orders.Clear()
    $docker.Called.Clear()
    $docker.RegistryVerdict = @{ Ok = $true; Why = "" }
    $docker.Responsive = $false
    $result = $presenter.Run()
    Check "a known reference goes on" "$($result.Status)/$($result.Message)" "Nok/Build : Docker is not responding."
    Check "  ... the packs offered whole, the note said" `
        ("$($view.PackOffer)/$($view.PackChecked)/$($view.PackNote)") "base,extra,oh_my_shell,solo//This recipe's system cannot be read - a pack made for another one will fail to install."
    Check "  ... the onboarding refused means no account" (@($view.Orders | Where-Object { $_ -eq "user" }).Count) 0
    Check "  ... and the docker refusal painted" ($view.Orders -contains "abort Docker is not responding. / Start Docker Desktop, then try again.") $true
    Check "  ... the reference checked, the sonde asked, nothing built" `
        (($docker.Called -join " | ") -eq "registry alpine:latest | running | desktop") $true
    $docker.Responsive = $true
    $docker.RegistryVerdict = @{ Ok = $false; Why = "no such image or tag on Docker Hub" }

    # 5. The Dockerfile road, to the end of the questions: the source's family
    # filters the packs and pre-ticks the shell, the account takes the
    # proposed Windows name on an empty answer, the Dockerfile road alone
    # asks about keeping the image - and the builder's refusal is a fault
    # painted by the error view.
    $view.NameAnswers = @("bench-build")
    $view.RoadAnswers = @("dockerfile")
    $view.SourcePicks = @("bench-b")
    $view.PackPicks = @("oh_my_shell")
    $view.BootPicks = @("bench-boot")
    $view.RunOnboarding = $true
    $view.UserAnswers = @("Root", "")
    $view.Keep = $true
    $view.Register = $true
    Reset-BuildAnswers $view
    $view.Orders.Clear()
    $failureView.Orders.Clear()
    $docker.Called.Clear()
    $fake.Called.Clear()
    $result = $presenter.Run()
    Check "the Dockerfile road runs to the builder" "$($result.Status)/$($result.Message)" "Nok/Build : bench-build - the builder refused"
    Check "  ... the source list asked, and the family filtered the packs" `
        ("$($view.PackOffer)/$($view.PackChecked)") "base,extra,oh_my_shell,solo/2"
    Check "  ... the account asked with the proposed name" ($view.LastUserPrompt.Contains("[jean-dupont]")) $true
    Check "  ... a refused account is hinted, the empty takes the proposal" `
        (($view.Orders -join " | ").Contains("account-breath | user | hint-user | user | keep | register")) $true
    Check "  ... and the conversation in order" `
        ($view.Orders -join " | ") "clear | name | clear | road dockerfile | source Dockerfile | clear | packs | onboarding-run | onboarding | account-breath | user | hint-user | user | keep | register"
    Check "  ... the builder called with the Dto's own shape" `
        (($docker.Called -join " | ") -like "running | build wsl-stack:bench-build*bench-b*") $true
    Check "  ... and the refusal painted" ($failureView.Orders -join " | ") "error the builder refused"

    # 6. A source folder with no Dockerfile, and one with no saved image:
    # each road's refusal is its own, and both are faults.
    $bare = [BuildPresenter]::new($BareService, (New-ViewsRoot), "cli")
    $bare.Views = @{ "Build" = $view; "Error" = $failureView }
    Reset-BuildAnswers $view
    $view.RoadAnswers = @("dockerfile")
    $view.Orders.Clear()
    $result = $bare.Run()
    Check "no Dockerfile is a fault" "$($result.Status)/$($result.Message)" "Nok/Build : no Dockerfile"
    Check "  ... with the refusal's own words" `
        ($view.Orders -contains "abort No Dockerfile under 'assets\dockerfiles'. / Upload one, or delete that folder to get the repository's own back. / Nothing was modified.") $true

    $view.RoadAnswers = @("image")
    Reset-BuildAnswers $view
    $view.Orders.Clear()
    $result = $bare.Run()
    Check "no saved image is its own fault" "$($result.Status)/$($result.Message)" "Nok/Build : no Docker image"
    Check "  ... with the refusal's own words" `
        ($view.Orders -contains "abort No Docker image under 'assets\dockerimages'. / Upload one, or pick another road. / Nothing was modified.") $true

    # 7. One row is the answer: no list is asked for it.
    $OneAssets = Join-Path $World "one-assets"
    New-Item -ItemType Directory -Path (Join-Path $OneAssets "dockerfiles\only-one") -Force | Out-Null
    Set-Content -Path (Join-Path $OneAssets "dockerfiles\only-one\Dockerfile") -Value "FROM debian:bookworm-slim"
    New-Item -ItemType Directory -Path (Join-Path $OneAssets "onboardings") -Force | Out-Null
    $OneService = [InstanceService]::new($instances, $archives, $fake, $terminal, $docker, $packs, [ConfigRepository]::new($OneAssets))
    $one = [BuildPresenter]::new($OneService, (New-ViewsRoot), "cli")
    $one.Views = @{ "Build" = $view; "Error" = $failureView }
    Reset-BuildAnswers $view
    $view.RoadAnswers = @("dockerfile")
    $view.PackPicks = @("ESCAPE")
    $view.Orders.Clear()
    $docker.Responsive = $false
    $result = $one.Run()
    Check "one row goes without a list" (@($view.Orders | Where-Object { $_ -like "source*" }).Count) 0
    Check "  ... the onboarding absent is said, not asked" ($view.Orders -contains "no-onboarding") $true
    Check "  ... and the checklist empty is said too" ($view.Orders -contains "no-pack") $true
    Check "  ... to the docker refusal" "$($result.Status)/$($result.Message)" "Nok/Build : Docker is not responding."
} finally {
    Remove-Item -Recurse -Force $World -ErrorAction SilentlyContinue
}

Write-Output ""
Write-Output ("failures: " + $Failures)
exit $Failures
