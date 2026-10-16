# The settings screen and the packs walk, driven through the navigation by a
# fake view: the menu of doors - migrate, wslconfig, and the packs of the
# catalog - then the catalog and its three choices, edit / duplicate / delete,
# each recorded by a fake service so every decision the checks read is the
# presenter's. A queue of answers lets one run walk several windows: what is
# read is the climb - an escape or an action's own cancel backing out one
# window at a time, re-reading what it returns to - the empty catalog, the
# empty name, the refused and the accepted removal, the fault.
#
# Usage:  pwsh -NoProfile -File tests\presenters\settings-presenter-test.ps1
using module ..\..\src\windows\Presenters\Fleet\SettingsPresenter.psm1
using module ..\..\src\windows\Presenters\Fleet\NavigationPresenter.psm1
using module ..\..\src\windows\Presenters\ActionResult.psm1
using module ..\..\src\windows\Services\PackCatalogService.psm1
using module ..\..\src\windows\Entities\WslPack.psm1
using module ..\..\src\windows\Entities\WslPackCatalog.psm1
using module ..\..\src\windows\Dtos\PackCatalogDto.psm1
using module ..\..\src\windows\Repositories\PackCatalogRepository.psm1
using module ..\..\src\windows\Views\cli\MenuCli.psm1
using module ..\support\common.psm1

class FakeCatalog : PackCatalogService {
    [System.Collections.Generic.List[string]]$Called
    [object[]]$Stock = @()
    [bool]$Refusal = $false

    FakeCatalog([string]$packsRoot) : base([WslPackCatalog]::new(), [PackCatalogRepository]::new($packsRoot)) {
        $this.Called = [System.Collections.Generic.List[string]]::new()
    }
    [WslPackDto[]] GetAllPacks() {
        if ($this.Refusal) { throw "the catalog did not read" }
        return @($this.Stock)
    }
    [void] OpenPackFolder([string]$packName) { $this.Called.Add("open $packName") }
    [string] CreatePack([CreatePackDto]$dto) {
        $this.Called.Add("create $($dto.SourceName) $($dto.NewName) $($dto.Description)")
        return "$($dto.NewName)"
    }
    [void] DeletePack([string]$packName) { $this.Called.Add("delete $packName") }
}

class FakeSettingsView {
    [System.Collections.Generic.List[string]]$Orders
    [string]$Choice = ""
    [string]$Pack = ""
    [string]$PackChoice = ""
    [string]$Name = ""
    [bool]$Yes = $false
    [System.Collections.Generic.List[string]]$ChoiceQueue
    [System.Collections.Generic.List[string]]$PackQueue
    [System.Collections.Generic.List[string]]$PackChoiceQueue

    FakeSettingsView() {
        $this.Orders = [System.Collections.Generic.List[string]]::new()
        $this.ChoiceQueue = [System.Collections.Generic.List[string]]::new()
        $this.PackQueue = [System.Collections.Generic.List[string]]::new()
        $this.PackChoiceQueue = [System.Collections.Generic.List[string]]::new()
    }

    [object] PickAction([string]$title, [object[]]$actions) {
        $this.Orders.Add("menu $((@($actions) | ForEach-Object { $_.Key }) -join ',')")
        $wanted = $this.Choice
        if ($this.ChoiceQueue.Count -gt 0) { $wanted = $this.ChoiceQueue[0]; $this.ChoiceQueue.RemoveAt(0) }
        foreach ($item in @($actions)) { if ("$($item.Key)" -eq $wanted) { return $item } }
        return $null
    }
    [object] PickPack([object[]]$packs) {
        $this.Orders.Add("packs $((@($packs) | ForEach-Object { $_.Name }) -join ',')")
        $wanted = $this.Pack
        if ($this.PackQueue.Count -gt 0) { $wanted = $this.PackQueue[0]; $this.PackQueue.RemoveAt(0) }
        foreach ($pack in @($packs)) { if ("$($pack.Name)" -eq $wanted) { return $pack } }
        return $null
    }
    [object] PickPackAction([string]$name) {
        $this.Orders.Add("choices of $name")
        $wanted = $this.PackChoice
        if ($this.PackChoiceQueue.Count -gt 0) { $wanted = $this.PackChoiceQueue[0]; $this.PackChoiceQueue.RemoveAt(0) }
        foreach ($key in @("edit", "duplicate", "delete")) {
            if ($key -eq $wanted) { return [pscustomobject]@{ Key = $key } }
        }
        return $null
    }
    [string] AskName([string]$current) { $this.Orders.Add("ask-name $current"); return $this.Name }
    [bool] Confirm([string]$question, [bool]$defaultNo) {
        $this.Orders.Add("confirm $question defaultNo=$defaultNo")
        return $this.Yes
    }
    [void] ShowOpening([string]$name) { $this.Orders.Add("opening $name") }
    [void] ShowDuplicated([string]$name) { $this.Orders.Add("duplicated $name") }
    [void] ShowRemoved([string]$name) { $this.Orders.Add("removed $name") }
    [void] ShowDependents([string]$name, [string[]]$names) { $this.Orders.Add("dependents of $name : $($names -join ',')") }
    [void] ShowNoPacks() { $this.Orders.Add("no-packs") }
}

$ErrorActionPreference = "Stop"

$global:Failures = 0

$PacksRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("settings-presenter-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $PacksRoot -Force | Out-Null

$catalog = [FakeCatalog]::new($PacksRoot)
$pack = [WslPackDto]::new()
$pack.Name = "oh_my_py"
$pack.Family = "debian"
$pack.Description = "Python 3, uv and ruff"
$catalog.Stock = @($pack)

$log = [System.Collections.Generic.List[string]]::new()
$presenters = @{ Log = $log }

function New-Action([string]$key, [string]$description) {
    return [MenuItemCli]::new($key, $description, { param($Name, $Presenters) $Presenters.Log.Add("ran"); [ActionResult]::Ok("Act") })
}

$actions = @(
    (New-Action "migrate" "move the fleet to another folder"),
    (New-Action "wslconfig" "open the Windows-wide WSL settings"),
    ([MenuItemCli]::new("availables packs", "edit, duplicate or delete a catalogue pack", $null))
)

$presenter = [SettingsPresenter]::new($catalog, (Join-Path $PSScriptRoot "..\..\src\windows\Views"), "cli", $actions)
$nav = [NavigationPresenter]::new($null, $presenter)

try {
    $view = [FakeSettingsView]::new()
    $failureView = [FakeErrorView]::new()
    $presenter.Views = @{ "Settings" = $view; "Error" = $failureView }

    # 1. The menu, in order; a fleet word picked leaves with the door's block,
    # and the walk ends there.
    $view.ChoiceQueue.Add("migrate")
    $result = $nav.Run("settings", $presenters)
    Check "the settings menu holds the three doors" ($view.Orders -join " | ") "menu migrate,wslconfig,availables packs"
    Check "  ... and migrate ran" ($log -join " | ") "ran"
    Check "  ... its result returned" "$($result.Status)/$($result.Message)" "Ok/Act"

    # 2. The packs door: the catalog, the pack, and edit opens its folder.
    $view.Orders.Clear()
    $view.ChoiceQueue.Add("availables packs")
    $view.PackQueue.Add("oh_my_py")
    $view.PackChoiceQueue.Add("edit")
    $result = $nav.Run("settings", $presenters)
    Check "the packs walk: catalog, choices, the folder" ($view.Orders -join " | ") "menu migrate,wslconfig,availables packs | packs oh_my_py | choices of oh_my_py | opening oh_my_py"
    Check "  ... the folder was opened" ($catalog.Called -join " | ") "open oh_my_py"
    Check "  ... and it ends there" "$($result.Status)/$($result.Message)" "Ok/Settings : oh_my_py"

    # 3. Duplicate asks the name, and the copy carries the source's own
    # description.
    $view.Orders.Clear()
    $catalog.Called.Clear()
    $view.ChoiceQueue.Add("availables packs")
    $view.PackQueue.Add("oh_my_py")
    $view.PackChoiceQueue.Add("duplicate")
    $view.Name = "copy-one"
    $result = $nav.Run("settings", $presenters)
    Check "the name was asked" ($view.Orders -contains "ask-name oh_my_py") $true
    Check "  ... and the copy was made" ($catalog.Called -join " | ") "create oh_my_py copy-one Python 3, uv and ruff"
    Check "  ... said, and the new name reported" "$($view.Orders -contains 'duplicated copy-one')/$($result.Message)" "True/Settings : copy-one"

    # 4. An empty name abandons the copy: nothing is created, and the walk
    # climbs back one window at a time - the catalog relit, then the menu -
    # ending at the root's escape.
    $view.Orders.Clear()
    $catalog.Called.Clear()
    $view.Name = ""
    $view.ChoiceQueue.Add("availables packs")
    $view.ChoiceQueue.Add("")
    $view.PackQueue.Add("oh_my_py")
    $view.PackQueue.Add("")
    $view.PackChoiceQueue.Add("duplicate")
    $result = $nav.Run("settings", $presenters)
    Check "an empty name comes back to the choices, then climbs" ($view.Orders -join " | ") "menu migrate,wslconfig,availables packs | packs oh_my_py | choices of oh_my_py | ask-name oh_my_py | choices of oh_my_py | packs oh_my_py | menu migrate,wslconfig,availables packs"
    Check "  ... nothing was created" $catalog.Called.Count 0
    Check "  ... and the root escape ends the run" "$($result.Status)/$($result.Message)" "Ok/Settings : cancelled"

    # 5. Delete asks, and a no climbs back the same way, the catalog alone.
    $view.Orders.Clear()
    $catalog.Called.Clear()
    $view.Name = "unused"
    $view.ChoiceQueue.Add("availables packs")
    $view.ChoiceQueue.Add("")
    $view.PackQueue.Add("oh_my_py")
    $view.PackQueue.Add("")
    $view.PackChoiceQueue.Add("delete")
    $view.Yes = $false
    $result = $nav.Run("settings", $presenters)
    Check "a no at the removal cancels" "$($result.Status)/$($result.Message)" "Ok/Settings : cancelled"
    Check "  ... after the question, default no" ($view.Orders -contains "confirm Remove the pack 'oh_my_py'? defaultNo=True") $true
    Check "  ... the catalog was relit, not asked" ($catalog.Called.Count -eq 0 -and $view.Orders -contains "packs oh_my_py") $true

    # 6. A yes deletes it.
    $view.Orders.Clear()
    $catalog.Called.Clear()
    $view.ChoiceQueue.Add("availables packs")
    $view.PackQueue.Add("oh_my_py")
    $view.PackChoiceQueue.Add("delete")
    $view.Yes = $true
    $result = $nav.Run("settings", $presenters)
    Check "a yes removes it" ($catalog.Called -join " | ") "delete oh_my_py"
    Check "  ... said, and reported" "$($view.Orders -contains 'removed oh_my_py')/$($result.Message)" "True/Settings : oh_my_py"

    # 7. The escapes, window by window: the menu at the root ends the run;
    # the catalog and the choices climb back, relit.
    $view.Orders.Clear()
    $catalog.Called.Clear()
    $view.ChoiceQueue.Add("")
    $result = $nav.Run("settings", $presenters)
    Check "the escape at the menu cancels" "$($result.Status)/$($result.Message)" "Ok/Settings : cancelled"
    Check "  ... after the menu alone" ($view.Orders -join " | ") "menu migrate,wslconfig,availables packs"

    $view.Orders.Clear()
    $view.ChoiceQueue.Add("availables packs")
    $view.ChoiceQueue.Add("")
    $view.PackQueue.Add("")
    $result = $nav.Run("settings", $presenters)
    Check "the escape at the catalog climbs to the menu" ($view.Orders -join " | ") "menu migrate,wslconfig,availables packs | packs oh_my_py | menu migrate,wslconfig,availables packs"
    Check "  ... and the run ends Ok" "$($result.Status)/$($result.Message)" "Ok/Settings : cancelled"

    $view.Orders.Clear()
    $view.ChoiceQueue.Add("availables packs")
    $view.ChoiceQueue.Add("")
    $view.PackQueue.Add("oh_my_py")
    $view.PackQueue.Add("")
    $view.PackChoiceQueue.Add("")
    $result = $nav.Run("settings", $presenters)
    Check "the escape at the choices climbs to the catalog" ($view.Orders -join " | ") "menu migrate,wslconfig,availables packs | packs oh_my_py | choices of oh_my_py | packs oh_my_py | menu migrate,wslconfig,availables packs"
    Check "  ... nothing ran" $catalog.Called.Count 0

    # 8. An empty catalog is said, and the menu comes back.
    $catalog.Stock = @()
    $view.Orders.Clear()
    $view.ChoiceQueue.Add("availables packs")
    $view.ChoiceQueue.Add("")
    $result = $nav.Run("settings", $presenters)
    Check "an empty catalog is painted" ($view.Orders -contains "no-packs") $true
    Check "  ... then the menu returns" ($view.Orders -join " | ") "menu migrate,wslconfig,availables packs | no-packs | menu migrate,wslconfig,availables packs"
    Check "  ... and the walk ends on the root escape" "$($result.Status)/$($result.Message)" "Ok/Settings : cancelled"
    $catalog.Stock = @($pack)

    # 9. A pack others depend on: the warning comes before the question, one
    # name per line, and a no still cancels without a removal.
    $view.Orders.Clear()
    $catalog.Called.Clear()
    $pack.Dependents = @("oh_my_web", "oh_my_code")
    $view.ChoiceQueue.Add("availables packs")
    $view.ChoiceQueue.Add("")
    $view.PackQueue.Add("oh_my_py")
    $view.PackQueue.Add("")
    $view.PackChoiceQueue.Add("delete")
    $view.Yes = $false
    $result = $nav.Run("settings", $presenters)
    Check "the dependents are said before the question" ($view.Orders -join " | ") "menu migrate,wslconfig,availables packs | packs oh_my_py | choices of oh_my_py | dependents of oh_my_py : oh_my_web,oh_my_code | confirm Remove the pack 'oh_my_py'? defaultNo=True | choices of oh_my_py | packs oh_my_py | menu migrate,wslconfig,availables packs"
    Check "  ... the no cancels" "$($result.Status)/$($result.Message)" "Ok/Settings : cancelled"
    Check "  ... nothing was removed" $catalog.Called.Count 0

    # 10. The yes goes, the dependents and all.
    $view.Orders.Clear()
    $catalog.Called.Clear()
    $view.ChoiceQueue.Add("availables packs")
    $view.PackQueue.Add("oh_my_py")
    $view.PackChoiceQueue.Add("delete")
    $view.Yes = $true
    $result = $nav.Run("settings", $presenters)
    Check "the yes removes it, after the same warning" ($catalog.Called -join " | ") "delete oh_my_py"
    Check "  ... and it is reported" "$($result.Status)/$($result.Message)" "Ok/Settings : oh_my_py"
    $pack.Dependents = @()

    # 11. A catalog that refuses to read is painted, and the menu comes back.
    $catalog.Refusal = $true
    $view.Orders.Clear()
    $view.ChoiceQueue.Add("availables packs")
    $view.ChoiceQueue.Add("")
    $result = $nav.Run("settings", $presenters)
    Check "a catalog that will not read is painted" ($failureView.Orders -join " | ") "error the catalog did not read"
    Check "  ... and the menu returns" ($view.Orders -join " | ") "menu migrate,wslconfig,availables packs | menu migrate,wslconfig,availables packs"
    Check "  ... the walk ending on the root escape" "$($result.Status)/$($result.Message)" "Ok/Settings : cancelled"
    $catalog.Refusal = $false
} finally {
    Remove-Item -Recurse -Force $PacksRoot -ErrorAction SilentlyContinue
}

Write-Output ""
Write-Output ("failures: " + $global:Failures)
exit $global:Failures
