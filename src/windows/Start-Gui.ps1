using module .\Services\ServiceFactory.psm1
using module .\ViewModels\MainWindowViewModel.psm1

[CmdletBinding()]
param()

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

$null = Import-Module (Join-Path $PSScriptRoot "Views\WPF\BaseViewWpf.psm1")
$baseView = $null
foreach ($assembly in [AppDomain]::CurrentDomain.GetAssemblies()) {
    try { $baseView = @($assembly.GetTypes() | Where-Object { $_.Name -eq "BaseViewWpf" })[0] } catch { }
    if ($baseView) { break }
}
if (-not $baseView) {
    Write-Host ""
    Write-Host "[ABORT] BaseViewWpf was not found - the src\windows\Views\WPF\ folder is incomplete." -ForegroundColor DarkRed
    exit 1
}

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Assets = Join-Path $RepoRoot "assets"
$distroTree = Join-Path $RepoRoot "src\distro"
if (-not (Test-Path $distroTree)) { $distroTree = "" }
$WpfViews = Join-Path $PSScriptRoot "Views\WPF"
$Runners = Join-Path $PSScriptRoot "Runners"

$root = [ServiceFactory]::ResolveRoot($Assets, $distroTree)
$fleet = [ServiceFactory]::CreateFleetService($root, $Assets, $distroTree)
$instances = [ServiceFactory]::CreateInstanceService($root, $Assets, $distroTree)
$wpfService = [ServiceFactory]::CreateWpfService($Assets)
$catalogue = [ServiceFactory]::CreatePackCatalogService($Assets)
$logger = [ServiceFactory]::CreateLoggerService()

$look = $wpfService.GetTheme()
$baseView::SetContext($look, $Assets)

$vm = [MainWindowViewModel]::new($instances, $fleet, $wpfService, $catalogue, $Assets, $Runners, $logger)

$vm.Ouverture = {
    param($gesture, $arguments)
    $answered = $vm.FindFace($WpfViews, $gesture, $arguments)
    if ($null -eq $answered) {
        $wanted = "Wpf${gesture}View"
        $known = $false
        foreach ($assembly in [AppDomain]::CurrentDomain.GetAssemblies()) {
            try { if (@($assembly.GetTypes() | Where-Object { $_.Name -eq $wanted }).Count -gt 0) { $known = $true } } catch { }
            if ($known) { break }
        }
        if (-not $known) { $vm.Fail("$gesture : the dialog '$wanted' was not found.") }
    }
    return $answered
}
$vm.Load()

Get-ChildItem -Path $WpfViews -Recurse -Filter "*.xaml.ps1" -File | ForEach-Object {
    try { $null = Import-Module $_.FullName -ErrorAction Stop } catch {
        Write-Host "[WARN] The view '$($_.Name)' did not load: $($_.Exception.Message)" -ForegroundColor DarkYellow
    }
}
$mainView = $null
foreach ($assembly in [AppDomain]::CurrentDomain.GetAssemblies()) {
    try { $mainView = @($assembly.GetTypes() | Where-Object { $_.Name -eq "WpfMainView" })[0] } catch { }
    if ($mainView) { break }
}
if (-not $mainView) {
    Write-Host ""
    Write-Host "[ABORT] WpfMainView was not found - the src\windows\Views\WPF\MainWindow\ folder is incomplete." -ForegroundColor DarkRed
    exit 1
}
$window = $mainView::new()
$null = $window.Ask($vm)
