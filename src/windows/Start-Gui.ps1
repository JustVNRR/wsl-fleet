# ==============================================================================
# L'ENTRÉE DU GUI — L'ASSEMBLAGE
# ==============================================================================
# La racine de la fenêtre : elle fait les services (par la fabrique — jamais
# un dépôt ici), le ViewModel — les services en main, il porte l'écran —,
# pose le contexte des fenêtres, et ouvre la fenêtre. Plus de contrôleurs,
# plus de portes ici : le CLI garde les siens ; le GUI passe par son
# ViewModel. La vue vit sa vie : le cadre de dispatcher, le battement, le
# volet et leur nettoyage vivent chez elle, avec son fil.
#
# L'ordre est compté : les `using` d'un script s'importent AVANT la première
# ligne qui court — la fabrique et le ViewModel sont du PowerShell pur (pas
# une once de WPF), ils passent ; la vue de base ÉTEND une fenêtre, elle
# s'importe APRÈS les Add-Type, et son type se résout à l'exécution.
using module .\Service\ServiceFactory.psm1
using module .\ViewModels\MainWindowViewModel.psm1

[CmdletBinding()]
param()

# 1. Les assemblages du WPF — et WinForms pour l'écran où la fenêtre vit.
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# La vue de base — le contexte des fenêtres y vit. Importée ici, pas en
# `using` : son import réclame les types du WPF, déjà chargés. Sans -Force :
# le cache du module porte la MÊME classe pour toutes les vues (deux
# chargements feraient deux contextes, et les statiques divergeraient).
# Une classe importée ainsi n'a PAS de nom ici — mesuré sur sa machine :
# « Impossible de trouver le type [BaseViewWpf] ». On la prend par le guet :
# la même recherche d'assemblée que la résolution des vues, et l'appel par
# la variable qui la tient.
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

# 2. Les dossiers : la racine du dépôt, deux crans au-dessus.
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Assets = Join-Path $RepoRoot "assets"
$distroTree = Join-Path $RepoRoot "src\distro"
if (-not (Test-Path $distroTree)) { $distroTree = "" }
$WpfViews = Join-Path $PSScriptRoot "Views\WPF"
$Runners = Join-Path $PSScriptRoot "Runners"

# 3. L'assemblage : la fabrique fait tout — la racine comprise, qu'elle
# demande à la flotte d'un passage. L'entrée ne voit jamais un dépôt.
$root = [ServiceFactory]::ResolveRoot($Assets, $distroTree)
$fleet = [ServiceFactory]::CreateFleetService($root, $Assets, $distroTree)
$instances = [ServiceFactory]::CreateInstanceService($root, $Assets, $distroTree)
$wpfService = [ServiceFactory]::CreateWpfService($Assets)
$catalogue = [ServiceFactory]::CreatePackCatalogService($Assets)

# Le contexte des fenêtres : le look et les dossiers — les polices (VT323,
# les glyphes), la fenêtre se les résout elle-même.
$look = $wpfService.GetTheme()
$baseView::SetContext($look, $Assets)

# 4. Le ViewModel — l'écran, ses états, ses commandes. Les services sont à
# lui ; les dossiers dont il a besoin (les ouvriers, les assets) voyagent en
# clair.
$vm = [MainWindowViewModel]::new($instances, $fleet, $wpfService, $catalogue, $Assets, $Runners)

# La porte d'ouverture : l'entrée pose où et comment on trouve une vue — le
# ViewModel, lui, dit seulement « ouvre la boîte X » (la même mécanique que
# sa porte de fermeture). Le guet d'assemblée reste ici : le type de base
# n'a pas de nom hors de son module (mesuré).
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

# 5. Les vues s'importent TOUTES ici, à la racine du script — la fenêtre
# comprise. Mesuré : l'import de PREMIÈRE fois d'une vue, lancé depuis la
# porte des gestes (BaseViewModel, que chaque vue chaîne en `using module`),
# se mord la queue — GetExportedTypeDefinitions s'appelle cent mille fois,
# « Impossible de créer une nouvelle page de garde pour la pile ». À la
# racine, sain. La porte ensuite ne fait que chercher le type au guet,
# comme la vue de base : son nom n'existe pas ici.
Get-ChildItem -Path $WpfViews -Recurse -Filter "*.xaml.ps1" -File | ForEach-Object {
    # -ErrorAction Stop: without it, a failed import is a non-terminating
    # error - the catch never fires and the view is missing in silence.
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
