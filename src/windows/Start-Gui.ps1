# ==============================================================================
# L'ENTRÉE DU GUI — L'ASSEMBLAGE
# ==============================================================================
# La racine de la fenêtre : elle fait les services (par la fabrique — jamais
# un dépôt ici), les contrôleurs, les portes des gestes que l'entrée seule
# peut tenir, pose le contexte des fenêtres, et ouvre la fenêtre. La vue vit
# sa vie : le cadre de dispatcher, la sentinelle, la bande et leur nettoyage
# vivent chez elle, avec son fil.
#
# L'ordre est compté : les `using` d'un script s'importent AVANT la première
# ligne qui court — la fabrique et les contrôleurs sont du PowerShell pur,
# ils passent ; la vue de base ÉTEND une fenêtre, elle s'importe APRÈS les
# Add-Type, et son type se résout à l'exécution.
using module .\Service\ServiceFactory.psm1
using module .\Controllers\InstanceController.psm1
using module .\Controllers\MainWindowController.psm1

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

# 2. Les dossiers : la racine du dépôt, deux crans au-dessus. Les vues
# vivent sous Views\ : c'est CE dossier que les contrôleurs prennent pour
# racine.
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Assets = Join-Path $RepoRoot "assets"
$distroTree = Join-Path $RepoRoot "src\distro"
if (-not (Test-Path $distroTree)) { $distroTree = "" }
$ViewsRoot = Join-Path $PSScriptRoot "Views"

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

# Les contrôleurs — et les portes des gestes, que l'entrée seule peut tenir :
# elle est le seul endroit qui tient tous les contrôleurs.
$instanceController = [InstanceController]::new($instances, $ViewsRoot, "WPF")
$mainController = [MainWindowController]::new($wpfService, $catalogue, $fleet, $instances, $Assets, $ViewsRoot, "WPF")
$gestures = [PSCustomObject]@{
    Build         = $instanceController.Build
    Open          = $instanceController.Open
    Remove        = $instanceController.Remove
    Compact       = $instanceController.Compact
    Archive       = $instanceController.Archive
    Restore       = $instanceController.Restore
    Duplicate     = $instanceController.Duplicate
    DeleteArchive = $instanceController.DeleteArchive
    SetAppearance = $instanceController.SetAppearance
    ManagePacks   = $instanceController.ManagePacks
}

# 4. La fenêtre s'ouvre et vit — le geste rend quand elle se ferme.
$null = $mainController.Main($gestures)
