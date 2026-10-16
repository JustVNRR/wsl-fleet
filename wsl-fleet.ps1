# ==============================================================================
# THE WAY IN
# ==============================================================================
# Une seule porte à la racine, et deux foyers : la fenêtre, la console. Nue,
# elle pose la question — flèches et Entrée, Échap pour abandonner. Avec un
# mot, la console le route ; gui et cli gardent leur sens.
#
#   .\wsl-fleet.ps1                la question
#   .\wsl-fleet.ps1 gui            la fenêtre
#   .\wsl-fleet.ps1 cli            le menu de la console
#   .\wsl-fleet.ps1 archive        une commande, par son mot
#   .\wsl-fleet.ps1 restore wagon_archive   par son nom
#
# Rien ne vit ici : l'assemblage et les gestes sont chez eux, sous
# src\windows\ — Start-Gui.ps1 et Start-Cli.ps1, les deux entrées.
using module .\src\windows\Views\cli\MenuCli.psm1

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Command,

    # Le nom, quand il est là : les gestes le prennent en premier — sans lui,
    # la vue du geste demande.
    [Parameter(Position = 1)]
    [string]$Name = ""
)

$Windows = Join-Path $PSScriptRoot "src\windows"
$Console = [ConsoleCli]::new()

function Test-Entry([string]$Script) {
    if (-not (Test-Path $Script)) {
        $Console.Line("", "")
        $Console.Line("[ABORT] $Script is missing - the src\windows\ folder is incomplete.", "error")
        exit 1
    }
}

# La fenêtre vit dans son propre processus : la console rend la main tout de
# suite, et l'exe qui nous a lancés avec elle.
function Start-GuiWindow {
    Start-Process -FilePath "pwsh" -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $Windows "Start-Gui.ps1")) -WindowStyle Hidden
}

# Avec un mot : la console route tout — gui ouvre la fenêtre, cli ouvre le
# menu, le reste part au menu de la console qui le connaît.
if ($Command) {
    $Word = "$Command".ToLower()
    if ($Word -eq "gui") {
        Test-Entry (Join-Path $Windows "Start-Gui.ps1")
        Start-GuiWindow
        exit 0
    }
    $Cli = Join-Path $Windows "Start-Cli.ps1"
    Test-Entry $Cli
    if ($Word -eq "cli") {
        & $Cli
    } else {
        & $Cli $Command $Name
    }
    exit $LASTEXITCODE
}

# Nue : la première question, comme les questions du dedans — le même menu.
$Menu = [MenuCli]::new("Wsl Fleet")
$Menu = $Menu.Add("gui", "WSL Fleet GUI", { })
$Menu = $Menu.Add("cli", "WSL Fleet CLI", { })
$Choice = $Menu.Prompt()
if (-not $Choice) { exit 1 }

$Script = Join-Path $Windows $(if ($Choice.Key -eq "gui") { "Start-Gui.ps1" } else { "Start-Cli.ps1" })
Test-Entry $Script
if ($Choice.Key -eq "gui") {
    Start-GuiWindow
    exit 0
}
& $Script
exit $LASTEXITCODE
