# The window's files, where they live now (src\windows\Views\WPF): every .xaml
# must be well-formed XML, every resource reference - in the theme and in the
# windows - must name a key the theme itself defines, every control a view
# looks up by name must exist in its markup, every {Binding} must land on a
# real property of the ViewModel its window binds to, the colour sets under
# assets\themes must be well-formed and tell only keys the theme knows, and
# the nine runners must parse, keep the one parameter family and the two
# argument lines the window feeds them.
#
# The binding check matters most: WPF reads a type's real .NET properties
# only - a ScriptProperty laid on by Add-Member is invisible, and a {Binding}
# to a name that is not there paints nothing, in silence.
#
# Usage:  pwsh -NoProfile -File tests\gui-test.ps1
using module ..\src\windows\ViewModels\BuildViewModel.psm1
using module ..\src\windows\ViewModels\ArchiveViewModel.psm1
using module ..\src\windows\ViewModels\CompactViewModel.psm1
using module ..\src\windows\ViewModels\RemoveViewModel.psm1
using module ..\src\windows\ViewModels\RestoreViewModel.psm1
using module ..\src\windows\ViewModels\DuplicateViewModel.psm1
using module ..\src\windows\ViewModels\DeleteArchiveViewModel.psm1
using module ..\src\windows\ViewModels\ManagePacksViewModel.psm1
using module ..\src\windows\ViewModels\SetAppearanceViewModel.psm1
using module ..\src\windows\ViewModels\SettingsViewModel.psm1
using module ..\src\windows\ViewModels\MainWindowViewModel.psm1
using module ..\src\windows\ViewModels\RootMoveViewModel.psm1
using module ..\src\windows\ViewModels\PackDuplicateViewModel.psm1
using module ..\src\windows\ViewModels\ConfirmViewModel.psm1

$bad = 0
$WpfRoot = (Get-Item (Join-Path $PSScriptRoot "..\src\windows\Views\WPF")).FullName

# 1. The XAML files: well-formed XML, each one.
$xamlFiles = @(Get-ChildItem $WpfRoot -Recurse -Filter *.xaml)
foreach ($f in $xamlFiles) {
    try {
        $null = [xml]([IO.File]::ReadAllText($f.FullName))
    } catch {
        Write-Host "::error file=$($f.FullName)::not well-formed XML"
        Write-Host "  $($_.Exception.Message)"
        $bad = 1
    }
}
Write-Host "$($xamlFiles.Count) .xaml file(s) read from Views\WPF."

# 2. The theme's own bookkeeping: every reference points at a key it defines.
$keys = @()
$themePath = Join-Path $WpfRoot "theme.xaml"
if (Test-Path $themePath) {
    $theme = [IO.File]::ReadAllText($themePath)
    $keys = @([regex]::Matches($theme, 'x:Key="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
    $refs = @([regex]::Matches($theme, '\{(?:Static|Dynamic)Resource ([A-Za-z][A-Za-z0-9]*)\}') | ForEach-Object { $_.Groups[1].Value })
    $missing = @($refs | Where-Object { $_ -notin $keys })
    if ($missing.Count -gt 0) {
        Write-Host "::error file=$themePath::a resource reference names a key the theme does not define"
        Write-Host "  missing: $($missing -join ', ')"
        $bad = 1
    }
    Write-Host "theme: $($keys.Count) key(s), $($refs.Count) reference(s)."

    # 2b. And the windows resolve the same way: a key that is neither in the
    # theme nor set by the code (IconFace, poured into the window's dictionary
    # by WearTheme) fails SILENTLY - WPF falls back without a word.
    $codeKeys = @("IconFace")
    $viewRefs = @{}
    foreach ($f in $xamlFiles) {
        foreach ($m in [regex]::Matches([IO.File]::ReadAllText($f.FullName), '\{(?:Static|Dynamic)Resource ([A-Za-z][A-Za-z0-9]*)\}')) {
            $viewRefs[$m.Groups[1].Value] = $true
        }
    }
    $missingView = @($viewRefs.Keys | Where-Object { $_ -notin $keys -and $_ -notin $codeKeys })
    if ($missingView.Count -gt 0) {
        Write-Host "::error file=$WpfRoot::a window references a key nothing defines"
        Write-Host "  missing: $($missingView -join ', ')"
        $bad = 1
    }
    Write-Host "views: $($viewRefs.Count) key(s) referenced."
} else {
    Write-Host "::error file=$themePath::the theme is not there"
    $bad = 1
}

# 3. The colour sets: well-formed, and every key they tell - the Dark and
#    Light block names excepted - exists in the theme. A misspelled one is
#    ignored in silence and keeps the default, near impossible to notice
#    by eye.
$setsRoot = Join-Path $PSScriptRoot "..\assets\themes"
$setFiles = if (Test-Path $setsRoot) { @(Get-ChildItem $setsRoot -Filter *.xaml) } else { @() }
foreach ($f in $setFiles) {
    try {
        $null = [xml]([IO.File]::ReadAllText($f.FullName))
    } catch {
        Write-Host "::error file=$($f.FullName)::not well-formed XML"
        $bad = 1
        continue
    }
    $setKeys = @([regex]::Matches([IO.File]::ReadAllText($f.FullName), 'x:Key="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
    $strange = @($setKeys | Where-Object { $_ -notin $keys -and $_ -notin @("Dark", "Light") })
    if ($strange.Count -gt 0) {
        Write-Host "::error file=$($f.FullName)::names a key the theme does not define"
        Write-Host "  unknown: $($strange -join ', ')"
        $bad = 1
    }
}
Write-Host "$($setFiles.Count) colour set(s) read."

# 4. Every control a view looks up by name must exist in some window's markup:
#    a typo here is not a red line but a crash at the popup's open, in the one
#    place no suite can open. The .xaml files are the truth, all of them
#    together - each Find("...") must land on a Name= somewhere.
$allXaml = [string]::Join("`n", @($xamlFiles | ForEach-Object { [IO.File]::ReadAllText($_.FullName) }))
$names = @()
foreach ($f in @(Get-ChildItem (Join-Path $WpfRoot -ChildPath ".") -Recurse -Filter *.xaml.ps1) + @(Get-Item (Join-Path $WpfRoot "BaseViewWpf.psm1"))) {
    foreach ($m in [regex]::Matches([IO.File]::ReadAllText($f.FullName), 'Find\("([A-Za-z0-9]+)"\)')) {
        $names += $m.Groups[1].Value
    }
}
$missingNames = @($names | Sort-Object -Unique | Where-Object { $allXaml -notmatch ('Name="' + [regex]::Escape($_) + '"') })
if ($missingNames.Count -gt 0) {
    Write-Host "::error file=$WpfRoot::a Find names a control no window declares"
    Write-Host "  missing: $($missingNames -join ', ')"
    $bad = 1
}
Write-Host "$($names.Count) Find call(s) read, $(@($names | Sort-Object -Unique).Count) name(s) found in the markup."

# 5. Every {Binding} lands on a real property of the ViewModel its window
#    binds to - the wall WPF keeps: a name that is not a real .NET property
#    of the type paints nothing, silently.
function BindNames([string]$path) {
    $text = [IO.File]::ReadAllText($path)
    $found = @()
    foreach ($m in [regex]::Matches($text, '\{Binding\s+([A-Za-z_][A-Za-z0-9_.]*)')) {
        $name = $m.Groups[1].Value
        if ($name -eq 'RelativeSource') { continue }
        if ($name.Contains('.')) { continue }
        if ($found -notcontains $name) { $found += $name }
    }
    return @($found)
}
$map = @(
    @{ X = 'Instance/Build.xaml';          T = @([BuildViewModel]) },
    @{ X = 'Instance/Archive.xaml';        T = @([ArchiveViewModel]) },
    @{ X = 'Instance/Compact.xaml';        T = @([CompactViewModel]) },
    @{ X = 'Instance/Remove.xaml';         T = @([RemoveViewModel]) },
    @{ X = 'Instance/Restore.xaml';        T = @([RestoreViewModel]) },
    @{ X = 'Instance/Duplicate.xaml';      T = @([DuplicateViewModel]) },
    @{ X = 'Instance/DeleteArchive.xaml';  T = @([DeleteArchiveViewModel]) },
    @{ X = 'Instance/ManagePacks.xaml';    T = @([ManagePacksViewModel], [PackRowViewModel]) },
    @{ X = 'Instance/SetAppearance.xaml';  T = @([SetAppearanceViewModel]) },
    @{ X = 'MainWindow/Main.xaml';         T = @([MainWindowViewModel], [InstanceRowViewModel]) },
    @{ X = 'MainWindow/Settings.xaml';     T = @([SettingsViewModel]) },
    @{ X = 'shared/RootMove.xaml';         T = @([RootMoveViewModel]) },
    @{ X = 'shared/PackDuplicate.xaml';    T = @([PackDuplicateViewModel]) },
    @{ X = 'shared/Confirm.xaml';          T = @([ConfirmViewModel]) }
)
foreach ($entry in $map) {
    $path = Join-Path $WpfRoot $entry.X
    foreach ($name in (BindNames $path)) {
        $found = $false
        foreach ($t in $entry.T) {
            if ($null -ne $t.GetProperty($name)) { $found = $true; break }
        }
        if (-not $found) {
            Write-Host "::error file=$path::{Binding $name} names no real property of $(@($entry.T | ForEach-Object { $_.Name }) -join ' / ')"
            $bad = 1
        }
    }
}
Write-Host "$($map.Count) window(s) checked, every binding landed."

# 6. The runners: they parse, they keep the one parameter family, and the two
#    argument lines the window feeds them stay pinned - a rewrite that
#    quietly changes the call is the bug this catches.
$runnersRoot = Join-Path $PSScriptRoot "..\src\windows\Runners"
$runners = @(Get-ChildItem $runnersRoot -Filter *.ps1)
$family = 'param\(\s*\[string\]\$Name,[\s\S]*?\[string\]\$Assets,\s*\[string\]\$Root\s*\)'
foreach ($f in $runners) {
    $text = [IO.File]::ReadAllText($f.FullName)
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$null, [ref]$errors)
    if ($errors.Count -gt 0) {
        Write-Host "::error file=$($f.FullName)::$($errors.Count) parse error(s)"
        foreach ($e in $errors) { Write-Host ("  line {0}: {1}" -f $e.Extent.StartLineNumber, $e.Message) }
        $bad = 1
    }
    if ($text -notmatch $family) {
        Write-Host "::error file=$($f.FullName)::the parameter family (Name, Arg1, Arg2, Assets, Root) is not the one the window feeds"
        $bad = 1
    }
}
$mainVm = [IO.File]::ReadAllText((Join-Path $PSScriptRoot "..\src\windows\ViewModels\MainWindowViewModel.psm1"))
$pins = @(
    @{ Pattern = 'Join-Path \$this\._runners "\$\(\$verb\)Runner\.ps1"';                      What = "the runner file named after the verb" },
    @{ Pattern = '"-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", "`"\$workerPath`"",'; What = "the hidden worker line" },
    @{ Pattern = '"`"\$name`"", "`"\$arg1`"", "`"`"", "`"\$\(\$this\._assets\)`"", "`"\$\(\$this\.Root\)`""';     What = "the hidden worker's five arguments" },
    @{ Pattern = '"-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"\$workerPath`"",';               What = "the visible console line" },
    @{ Pattern = '"`"\$name`"", "`"\$arg1`"", "`"\$arg2`"", "`"\$\(\$this\._assets\)`"", "`"\$\(\$this\.Root\)`""'; What = "the visible console's five arguments" }
)
foreach ($pin in $pins) {
    if ($mainVm -notmatch $pin.Pattern) {
        Write-Host "::error file=MainWindowViewModel.psm1::no longer carries $($pin.What)"
        $bad = 1
    }
}
Write-Host "$($runners.Count) runner(s) read, $($pins.Count) call(s) pinned."

Write-Host "gui: $($xamlFiles.Count + $setFiles.Count + $runners.Count) file(s), $bad failure(s)."
exit $bad
