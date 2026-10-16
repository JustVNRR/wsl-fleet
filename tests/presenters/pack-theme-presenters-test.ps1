# The two traversals of the third lot, driven by fake views: manage_packs
# and theme (the look's visit) - each presenter runs
# its whole conversation with no console anywhere: the views record what they
# are told and replay what they are asked, and every decision (the empty
# catalogue, the escape, the confirmation, the ticked boxes, the letters'
# shape, the image's path, the Dto) is the presenter's.
#
# The service is the real one over a world of the suite's own: repositories on
# a temp root, a stand-in WslRepository recording every pack move, the pack
# catalogue read from a packs folder of the suite's, and stand-in terminal and
# config repositories for the look - so the two traversals run anywhere, the
# sandbox and the runner alike.
#
# Usage:  pwsh -NoProfile -File tests\presenters\pack-theme-presenters-test.ps1
using module ..\..\src\windows\Presenters\Instance\ManagePacksPresenter.psm1
using module ..\..\src\windows\Presenters\Instance\SetAppearancePresenter.psm1
using module ..\..\src\windows\Repositories\WslRepository.psm1
using module ..\..\src\windows\Repositories\InstanceRepository.psm1
using module ..\..\src\windows\Repositories\ArchiveRepository.psm1
using module ..\..\src\windows\Repositories\TerminalRepository.psm1
using module ..\..\src\windows\Repositories\DockerRepository.psm1
using module ..\..\src\windows\Repositories\PackCatalogRepository.psm1
using module ..\..\src\windows\Repositories\ConfigRepository.psm1
using module ..\..\src\windows\Entities\WslInstance.psm1
using module ..\..\src\windows\Entities\WslTheme.psm1
using module ..\..\src\windows\Services\InstanceService.psm1
using module ..\support\common.psm1


# The look's side, faked whole: the theme this instance carries, the fragment
# there or not, the guid, and the drawing - every call recorded. The fonts
# and the schemes are what the service reads through it.
class FakeTerminal : TerminalRepository {
    [System.Collections.Generic.List[string]]$Called
    [string]$Font = "MesloLGS NF"
    [string]$Scheme = "One Half Dark"
    [string]$IconText = ""
    [bool]$Fragment = $true
    [string]$Guid = "guid-bench"
    [object[]]$TerminalFonts = @()
    [object[]]$Schemes = @()
    [object[]]$Pairs = @()

    FakeTerminal() : base([System.IO.Path]::GetTempPath()) {
        $this.Called = [System.Collections.Generic.List[string]]::new()
    }

    [WslTheme] GetAppearance([string]$instanceName) {
        $theme = [WslTheme]::Default($instanceName)
        $theme.SetFont($this.Font)
        $theme.SetColourScheme($this.Scheme)
        $theme.SetIcon([PSCustomObject]@{ Text = $this.IconText; Top = ""; Bottom = ""; TextColor = "" })
        return $theme
    }

    [bool] HasFragment([string]$instanceName) { return $this.Fragment }
    [string] GetProfileGuid([string]$instanceName) { return $this.Guid }

    [void] SaveFragment([string]$instanceName, [string]$guid, [WslTheme]$theme) {
        $drawing = $theme.GetIcon()
        $this.Called.Add("savefragment $guid font=$($theme.GetFontName()) scheme=$($theme.GetColorScheme()) icon=$($drawing.Text)|$($drawing.Top)|$($drawing.Bottom)|$($drawing.TextColor)")
    }

    [void] TouchSettings() { $this.Called.Add("touch") }
    [object[]] GetTerminalFonts() { return @($this.TerminalFonts) }
    [object[]] GetColorSchemes() { return @($this.Schemes) }
    [object[]] GetIconPairs() { return @($this.Pairs) }

    [object] DrawIcon([string]$instanceName, [string]$outputPath, [object]$drawing) {
        $this.Called.Add("draw $($drawing.Text)")
        return [PSCustomObject]@{
            Text = "$($drawing.Text)"; Top = "$($drawing.Top)"
            Bottom = "$($drawing.Bottom)"; TextColor = "$($drawing.TextColor)"
        }
    }
}

# The reading of the shipped fonts, faked: it is Windows that knows how to
# read a folder of fonts, and the suite does not depend on it.
class FakeConfig : ConfigRepository {
    [string[]]$FontNames = @()

    FakeConfig() : base([System.IO.Path]::GetTempPath()) {}

    [string[]] GetFontNames() { return @($this.FontNames) }
    [string[]] GetPromptFontNames() { return @($this.FontNames) }
}

# The view fakes: every order recorded, every question answered from a script.
# A view that decided would hide what the presenter decides.
class FakeManagePacksView {
    [System.Collections.Generic.List[string]]$Orders
    [string[]]$Ticked = @()
    [bool]$Escape = $false

    FakeManagePacksView() { $this.Orders = [System.Collections.Generic.List[string]]::new() }

    [void] ShowNothingToChoose([string]$name) { $this.Orders.Add("nothing-to-choose $name") }
    [object[]] AskPacks([string]$name, [object[]]$rows, [int[]]$checkedIndexes) {
        $this.Orders.Add("ask rows=$($rows.Name -join ',') checked=$($checkedIndexes -join ',')")
        if ($this.Escape) { return $null }
        $chosen = @()
        foreach ($row in @($rows)) {
            if ($this.Ticked -contains "$($row.Name)") { $chosen += $row }
        }
        return $chosen
    }
    [void] ShowNothingToDo([string]$name) { $this.Orders.Add("nothing-to-do $name") }
    [void] ShowPlan([string[]]$toAdd, [string[]]$toRemove) {
        $this.Orders.Add("plan [$($toAdd -join ',')] / [$($toRemove -join ',')]")
    }
    [void] ShowCancelled([string]$what) { $this.Orders.Add("cancelled $what") }
    [void] Show([object]$response) {
        $this.Orders.Add("report $($response.Outcome) failed=$($response.Failed -join ',') installed=$($response.Installed -join ',') removed=$($response.Removed -join ',')")
    }
}

class FakeThemeView {
    [System.Collections.Generic.List[string]]$Orders
    [string[]]$ThemeAnswers = @()
    [string[]]$FontAnswers = @()
    [string[]]$ColourAnswers = @()
    [string[]]$TypeAnswers = @()
    [string[]]$LetterAnswers = @()
    [string[]]$PairAnswers = @()
    [string[]]$ImageAnswers = @()
    [int]$ThemeAt = 0
    [int]$FontAt = 0
    [int]$ColourAt = 0
    [int]$TypeAt = 0
    [int]$LetterAt = 0
    [int]$PairAt = 0
    [int]$ImageAt = 0
    [string]$FontList = ""
    [string]$SchemeList = ""
    [string]$PairList = ""

    FakeThemeView() { $this.Orders = [System.Collections.Generic.List[string]]::new() }

    hidden [string] Next([string[]]$answers, [int]$at) {
        if ($at -lt $answers.Count) { return "$($answers[$at])" }
        return ""
    }

    [void] ShowNoFragmentWarning() { $this.Orders.Add("warning") }
    [void] ClearScreen() { $this.Orders.Add("clear") }

    [string] AskTheme([string]$name) {
        $answer = $this.Next($this.ThemeAnswers, $this.ThemeAt)
        $this.ThemeAt++
        $this.Orders.Add("theme $answer")
        return $answer
    }

    [string] AskFont([string]$name, [string[]]$fonts, [string]$current) {
        $this.FontList = "$($fonts -join ',')"
        $answer = $this.Next($this.FontAnswers, $this.FontAt)
        $this.FontAt++
        $this.Orders.Add("font $answer current=$current")
        return $answer
    }

    [string] AskColour([string]$name, [object[]]$schemes, [string]$current) {
        $this.SchemeList = "$($schemes.Name -join ',')"
        $answer = $this.Next($this.ColourAnswers, $this.ColourAt)
        $this.ColourAt++
        $this.Orders.Add("colour $answer current=$current")
        return $answer
    }

    [string] AskIconType([string]$name) {
        $answer = $this.Next($this.TypeAnswers, $this.TypeAt)
        $this.TypeAt++
        $this.Orders.Add("icon-type $answer")
        return $answer
    }

    [string] AskLetters([string]$question) {
        $answer = $this.Next($this.LetterAnswers, $this.LetterAt)
        $this.LetterAt++
        $this.Orders.Add("letters [$question] $answer")
        return $answer
    }

    [void] ShowLettersHint() { $this.Orders.Add("hint") }

    [object] AskIconPair([string]$name, [object[]]$pairs, [string]$suggestion, [string]$currentTop, [string]$currentBottom) {
        $this.PairList = "$($pairs.Name -join ',')"
        $answer = $this.Next($this.PairAnswers, $this.PairAt)
        $this.PairAt++
        $this.Orders.Add("pair suggestion=$suggestion current=$currentTop/$currentBottom")
        if (-not $answer) { return "" }
        $parts = $answer -split '\|'
        return [PSCustomObject]@{ Name = "picked"; Top = $parts[0]; Bottom = $parts[1]; TextColor = $parts[2] }
    }

    [string] AskImagePath() {
        $answer = $this.Next($this.ImageAnswers, $this.ImageAt)
        $this.ImageAt++
        $this.Orders.Add("image-path $answer")
        return $answer
    }

    [void] ShowNoFile() { $this.Orders.Add("nofile") }
    [void] ShowBadExtension() { $this.Orders.Add("badext") }
    [void] ShowCancelled([string]$what) { $this.Orders.Add("cancelled $what") }
    [void] Show([object]$response) { $this.Orders.Add("report $(@($response.Changes) -join ';')") }
}


$ErrorActionPreference = "Stop"

$global:Failures = 0

# The world: the redirected profile, a root of the suite's own with one
# instance carrying the marker and its disk, and a packs folder whose
# declarations are the catalogue - base, extra (which requires base), solo,
# and one invisible pack nobody offers.
$World = Join-Path ([System.IO.Path]::GetTempPath()) ("pack-theme-presenters-" + [Guid]::NewGuid().ToString("N"))
$env:USERPROFILE = $World
$env:LOCALAPPDATA = Join-Path $World "LocalAppData"
$env:APPDATA = Join-Path $World "AppData"
New-Item -ItemType Directory -Path $env:LOCALAPPDATA -Force | Out-Null
New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
$Root = Join-Path $World "WSL"
$Instance = "bench-agent"
$FakeFolder = Join-Path $Root $Instance

$PacksRoot = Join-Path $World "packs"
$PacksDirectory = "/home/u/.config/packs"
function Add-Pack {
    param([string]$Name, [string]$Description, [string]$Requires, [string]$Visible)
    $Folder = Join-Path $PacksRoot $Name
    New-Item -ItemType Directory -Path $Folder -Force | Out-Null
    $Conf = @("PACK_DESCRIPTION := $Description")
    if ($Requires) { $Conf += "PACK_REQUIRES := $Requires" }
    if ($Visible) { $Conf += "PACK_VISIBLE := $Visible" }
    Set-Content -Path (Join-Path $Folder "pack.conf") -Value $Conf
}
Add-Pack -Name "base"   -Description "The base layer"
Add-Pack -Name "extra"  -Description "An extra pack" -Requires "base"
Add-Pack -Name "solo"   -Description "A lone pack"
Add-Pack -Name "hidden" -Description "An invisible pack" -Visible "no"

# Two files for the image question: one of the wrong shape, one of the right.
Set-Content -Path (Join-Path $World "icon.txt") -Value "not an image" -NoNewline
Set-Content -Path (Join-Path $World "icon.png") -Value "fake-png" -NoNewline

function Reset-World {
    Remove-Item -Recurse -Force $Root -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $FakeFolder -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $FakeFolder ".wsl-fleet") -Force | Out-Null
    Set-Content -Path (Join-Path $FakeFolder "ext4.vhdx") -Value "fake-disk" -NoNewline
}
Reset-World

# The instance's own file with the tile's recipe - the letters question needs
# something to suggest.
function Seed-Recipe {
    Set-Content -Path (Join-Path $FakeFolder "instance.json") -Encoding Utf8 -Value '{
        "DefaultUser": "",
        "Theme": {
            "Font": "MesloLGS NF",
            "ColorScheme": "One Half Dark",
            "IconText": "XX",
            "IconTop": "#111111",
            "IconBottom": "#222222",
            "IconTextColor": "#FFFFFF"
        }
    }'
}

$instances = [InstanceRepository]::new($Root)
$archives = [ArchiveRepository]::new((Join-Path $Root "archives"))
$docker = [DockerRepository]::new($Root)
$packs = [PackCatalogRepository]::new($PacksRoot)
$fake = [FakeWsl]::new()
$fake.Distros = @($Instance)
$terminal = [FakeTerminal]::new()
$config = [FakeConfig]::new()
$service = [InstanceService]::new($instances, $archives, $fake, $terminal, $docker, $packs, $config)

function New-ViewsRoot {
    return (Join-Path $PSScriptRoot "..\..\src\windows\Views")
}

# A scene's answers live in the view's counters: each scene resets them
# before it replays.
function Reset-ThemeAnswers {
    param([FakeThemeView]$View)
    $View.ThemeAt = 0; $View.FontAt = 0; $View.ColourAt = 0
    $View.TypeAt = 0; $View.LetterAt = 0; $View.PairAt = 0; $View.ImageAt = 0
}

try {
    # ---- manage_packs ------------------------------------------------------

    $manageView = [FakeManagePacksView]::new()
    $selectView = [FakeSelectView]::new()
    $selectView.Answer = $Instance
    $presenter = [ManagePacksPresenter]::new($service, (New-ViewsRoot), "cli")
    $presenter.Views = @{ "ManagePacks" = $manageView }
    $presenter.Picker.Views = @{ "SelectInstance" = $selectView }

    # 6. Nothing to choose and nothing to add: the answer is said - a second
    # service over a packs folder with no pack at all.
    Reset-World
    $EmptyPacks = Join-Path $World "packs-empty"
    New-Item -ItemType Directory -Path $EmptyPacks -Force | Out-Null
    $BareService = [InstanceService]::new($instances, $archives, $fake, $terminal, $docker, [PackCatalogRepository]::new($EmptyPacks), $config)
    $bare = [ManagePacksPresenter]::new($BareService, (New-ViewsRoot), "cli")
    $bare.Views = @{ "ManagePacks" = $manageView }
    $bare.Picker.Views = @{ "SelectInstance" = $selectView }
    $fake.Installed = @()
    $manageView.Orders.Clear()
    $result = $bare.Run("")
    Check "a bare catalogue is an answer" "$($result.Status)/$($result.Message)" "Ok/ManagePacks : cancelled"
    Check "  ... said once" ($manageView.Orders -join " | ") "nothing-to-choose $Instance"

    # 7. The lines: the offered ones unchecked first, then the carried ones
    # checked - extra is carried, so it is the third line and the only box.
    $fake.Installed = @("extra")
    $manageView.Escape = $true
    $manageView.Orders.Clear()
    $result = $presenter.Run("")
    Check "the escape abandons" "$($result.Status)/$($result.Message)" "Ok/ManagePacks : cancelled"
    Check "  ... the lines built and the boxes placed" ($manageView.Orders -join " | ") "ask rows=base,solo,extra checked=2 | cancelled modified"

    # 8. Exactly that: the box of what is carried stays the only one ticked.
    $manageView.Escape = $false
    $manageView.Ticked = @("extra")
    $manageView.Orders.Clear()
    $fake.Called.Clear()
    $result = $presenter.Run("")
    Check "the state already there is nothing to do" ($manageView.Orders -join " | ") "ask rows=base,solo,extra checked=2 | nothing-to-do $Instance"
    Check "  ... and nothing moved" (@($fake.Called | Where-Object { $_ -like "copy-to*" -or $_ -like "rm-folder*" -or $_ -like "script*" -or $_ -like "door-*" }).Count) 0

    # 9. A tick more installs it - the plan is said, then the moves.
    Reset-World
    $fake.Installed = @("extra")
    $manageView.Ticked = @("base", "extra")
    $manageView.Orders.Clear()
    $fake.Called.Clear()
    $result = $presenter.Run("")
    Check "the ticked pack goes in" "$($result.Status)/$($result.Message)" "Ok/ManagePacks : $Instance"
    Check "  ... the plan said first" ($manageView.Orders -contains "plan [base] / []") $true
    Check "  ... the plan before the moves" `
        (($manageView.Orders.IndexOf("plan [base] / []")) -lt ($fake.Called.IndexOf("copy-to $PacksDirectory/base"))) $true
    Check "  ... and the report reads the listing" ($manageView.Orders -contains "report ok failed= installed=base removed=") $true

    # 10. A pack that fails mid-course names the failli, and the report says
    # what stayed.
    Reset-World
    $fake.Installed = @("extra")
    $fake.FailScript = "install.sh"
    $manageView.Ticked = @("base", "extra")
    $manageView.Orders.Clear()
    $fake.Called.Clear()
    $result = $presenter.Run("")
    Check "a failed move is reported" ($manageView.Orders -contains "report failed failed=base installed= removed=") $true
    $fake.FailScript = ""

    # 11. A still-required untick is refused by the service, and the refusal
    # is a fault - painted by the error view, read as a Nok.
    Reset-World
    $fake.Installed = @("base", "extra")
    $failureView = [FakeErrorView]::new()
    $presenter.Views = @{ "ManagePacks" = $manageView; "Error" = $failureView }
    $manageView.Ticked = @("extra")
    $manageView.Orders.Clear()
    $fake.Called.Clear()
    $result = $presenter.Run("")
    Check "a required untick is a fault" "$($result.Status)" "Nok"
    Check "  ... painted by the error view" ($failureView.Orders -join " | ") "error 'base' cannot be removed: required by extra."
    Check "  ... and no move was made" (@($fake.Called | Where-Object { $_ -like "rm-folder*" }).Count) 0

    # ---- theme (setappearance) ---------------------------------------------

    $themeView = [FakeThemeView]::new()
    $selectView = [FakeSelectView]::new()
    $selectView.Answer = $Instance
    $failureView = [FakeErrorView]::new()
    $presenter = [SetAppearancePresenter]::new($service, (New-ViewsRoot), "cli")
    $presenter.Views = @{ "SetAppearance" = $themeView; "Error" = $failureView }
    $presenter.Picker.Views = @{ "SelectInstance" = $selectView }

    # 12. An empty machine: a fault; and the escape at the menu abandons
    # without a single call to the look.
    $fake.Distros = @()
    $result = $presenter.Run("")
    Check "theme on an empty machine is a fault" "$($result.Status)/$($result.Message)" "Nok/SetAppearance : no instance"
    $fake.Distros = @($Instance)
    Reset-World
    Reset-ThemeAnswers $themeView
    $themeView.ThemeAnswers = @("")
    $themeView.Orders.Clear()
    $terminal.Called.Clear()
    $result = $presenter.Run("")
    Check "the escape at the menu abandons" "$($result.Status)/$($result.Message)" "Ok/SetAppearance : cancelled"
    Check "  ... after the menu and one last breath" ($themeView.Orders -join " | ") "clear | theme  | clear"
    Check "  ... and the look was never written" ($terminal.Called.Count) 0

    # 13. The warning when our fragment is missing, and the font change: the
    # in-use font is offered whatever it carries, the pick is written into
    # the profile, and the report is the service's list.
    Reset-World
    Reset-ThemeAnswers $themeView
    $themeView.Orders.Clear()
    $terminal.Called.Clear()
    $terminal.Fragment = $false
    $terminal.Font = "Missing Font"
    $terminal.TerminalFonts = @([PSCustomObject]@{ Name = "FiraCode NF" })
    $config.FontNames = @("MesloLGS NF")
    $themeView.ThemeAnswers = @("font", "")
    $themeView.FontAnswers = @("FiraCode NF", "")
    $result = $presenter.Run("")
    Check "the font change goes" "$($result.Status)/$($result.Message)" "Ok/SetAppearance : $Instance"
    Check "  ... the missing-fragment warning first" ($themeView.Orders[0]) "warning"
    Check "  ... the in-use font offered whatever it carries" ($themeView.FontList) "MesloLGS NF,FiraCode NF,Missing Font"
    Check "  ... the mark read on each asking" (($themeView.Orders -join " | ").Contains("font FiraCode NF current=Missing Font | clear | font  current=FiraCode NF")) $true
    Check "  ... and the profile written with it" ($terminal.Called -join " | ") "savefragment guid-bench font=FiraCode NF scheme=One Half Dark icon=||| | touch"
    # The instance's own file, written too - the font is kept there.
    Check "  ... the instance's file carries it" ((Get-Content (Join-Path $FakeFolder "instance.json") -Raw) -match "FiraCode NF") $true
    $terminal.Fragment = $true

    # 14. The colours: each line painted of its scheme, and the pick written.
    Reset-World
    Reset-ThemeAnswers $themeView
    $themeView.Orders.Clear()
    $terminal.Called.Clear()
    $terminal.Font = "MesloLGS NF"
    $terminal.TerminalFonts = @()
    $config.FontNames = @()
    $terminal.Schemes = @(
        [PSCustomObject]@{ Name = "One Half Light"; Background = "#FAFAFA"; Foreground = "#383A42" },
        [PSCustomObject]@{ Name = "One Half Dark";  Background = "#282C34"; Foreground = "#DCDFE4" }
    )
    $themeView.ThemeAnswers = @("color", "")
    $themeView.ColourAnswers = @("One Half Light", "")
    $result = $presenter.Run("")
    Check "the colour change goes" "$($result.Status)/$($result.Message)" "Ok/SetAppearance : $Instance"
    Check "  ... the schemes read are the service's" ($themeView.SchemeList) "One Half Light,One Half Dark"
    Check "  ... the current one marked" (($themeView.Orders -join " | ").Contains("colour One Half Light current=One Half Dark")) $true
    Check "  ... and the profile written with it" ($terminal.Called -join " | ") "savefragment guid-bench font=MesloLGS NF scheme=One Half Light icon=||| | touch"

    # 15. The letters: a refused shape is hinted, a good one taken up-cased,
    # and Enter takes the suggestion - the recipe seeded at XX.
    Reset-World
    Seed-Recipe
    Reset-ThemeAnswers $themeView
    $themeView.Orders.Clear()
    $terminal.Called.Clear()
    $terminal.Font = "MesloLGS NF"
    $themeView.ThemeAnswers = @("icon", "")
    $themeView.TypeAnswers = @("letters", "")
    $themeView.LetterAnswers = @("abc4", "ab")
    $result = $presenter.Run("")
    Check "the letters change goes" "$($result.Status)/$($result.Message)" "Ok/SetAppearance : $Instance"
    Check "  ... the refused shape hinted" (@($themeView.Orders | Where-Object { $_ -eq "hint" }).Count) 1
    Check "  ... the question carrying the suggestion" (($themeView.Orders -join " | ").Contains("letters [Letters, 1 to 3 [XX]] abc4")) $true
    Check "  ... and the drawing written up-cased" ($terminal.Called -contains "savefragment guid-bench font=MesloLGS NF scheme=One Half Dark icon=AB|#111111|#222222|#FFFFFF") $true

    Reset-World
    Seed-Recipe
    Reset-ThemeAnswers $themeView
    $themeView.Orders.Clear()
    $terminal.Called.Clear()
    $terminal.Font = "MesloLGS NF"
    $themeView.TypeAnswers = @("letters", "")
    $themeView.LetterAnswers = @("")
    $themeView.ThemeAnswers = @("icon", "")
    $result = $presenter.Run("")
    Check "Entrée takes the suggestion" ($terminal.Called -contains "savefragment guid-bench font=MesloLGS NF scheme=One Half Dark icon=XX|#111111|#222222|#FFFFFF") $true

    # 16. The tile's colours: the pair picked replaces top and bottom, and the
    # suggestion rides into the question.
    Reset-World
    Seed-Recipe
    Reset-ThemeAnswers $themeView
    $themeView.Orders.Clear()
    $terminal.Called.Clear()
    $terminal.Font = "MesloLGS NF"
    $terminal.Pairs = @([PSCustomObject]@{ Name = "Pair A"; Top = "#0C0C0C"; Bottom = "#1F1F1F"; TextColor = "#FFFFFF" })
    $themeView.ThemeAnswers = @("icon", "")
    $themeView.TypeAnswers = @("colours", "")
    $themeView.PairAnswers = @("#0C0C0C|#1F1F1F|#FFFFFF", "")
    $result = $presenter.Run("")
    Check "the pair change goes" "$($result.Status)/$($result.Message)" "Ok/SetAppearance : $Instance"
    Check "  ... the suggestion and the current mark carried" ($themeView.Orders -contains "pair suggestion=XX current=#111111/#222222") $true
    Check "  ... the pairs read are the service's" ($themeView.PairList) "Pair A"
    Check "  ... and the drawing written with the pair" ($terminal.Called -contains "savefragment guid-bench font=MesloLGS NF scheme=One Half Dark icon=XX|#0C0C0C|#1F1F1F|#FFFFFF") $true

    # 17. By Default: the recipe emptied - make-icon fills it from the name.
    Reset-World
    Reset-ThemeAnswers $themeView
    $themeView.Orders.Clear()
    $terminal.Called.Clear()
    $terminal.Font = "MesloLGS NF"
    $terminal.Pairs = @()
    $themeView.ThemeAnswers = @("icon", "")
    $themeView.TypeAnswers = @("auto", "")
    $result = $presenter.Run("")
    Check "By Default goes" "$($result.Status)/$($result.Message)" "Ok/SetAppearance : $Instance"
    Check "  ... the drawing emptied, image included" ($terminal.Called -contains "savefragment guid-bench font=MesloLGS NF scheme=One Half Dark icon=|||") $true

    # 18. The local file: a missing path and a wrong shape are refused, the
    # right one is copied to the seat - and the profile is not rewritten.
    Reset-World
    Reset-ThemeAnswers $themeView
    $themeView.Orders.Clear()
    $terminal.Called.Clear()
    $themeView.ThemeAnswers = @("icon", "")
    $themeView.TypeAnswers = @("image", "")
    $themeView.ImageAnswers = @("nope.png", (Join-Path $World "icon.txt"), (Join-Path $World "icon.png"))
    $result = $presenter.Run("")
    Check "the image change goes" "$($result.Status)/$($result.Message)" "Ok/SetAppearance : $Instance"
    Check "  ... the missing path and the wrong shape refused, in order" `
        ((($themeView.Orders -join " | ").Contains("nofile | image-path")) -and (($themeView.Orders -join " | ").Contains("badext | image-path"))) $true
    Check "  ... the file copied to the seat" (Test-Path (Join-Path $FakeFolder "terminal-icon.png")) $true
    Check "  ... and the profile untouched" (@($terminal.Called | Where-Object { $_ -like "savefragment*" }).Count) 0
    Check "  ... the report saying the image went in" ($themeView.Orders -contains "report icon image") $true

    # 19. A look asked without a Terminal profile to write: the service
    # refuses, and the refusal is a fault.
    Reset-World
    Reset-ThemeAnswers $themeView
    $themeView.Orders.Clear()
    $terminal.Called.Clear()
    $terminal.Guid = ""
    $themeView.ThemeAnswers = @("font", "")
    $themeView.FontAnswers = @("FiraCode NF", "")
    $result = $presenter.Run("")
    Check "no profile is a fault" "$($result.Status)" "Nok"
    Check "  ... painted by the error view" `
        (($failureView.Orders -join " | ") -contains "error Windows Terminal has no profile for '$Instance' - the look cannot be applied.") $true
    $terminal.Guid = "guid-bench"
} finally {
    Remove-Item -Recurse -Force $World -ErrorAction SilentlyContinue
}

Write-Output ""
Write-Output ("failures: " + $global:Failures)
exit $global:Failures
