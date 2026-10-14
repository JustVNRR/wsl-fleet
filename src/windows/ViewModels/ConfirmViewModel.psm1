# ==============================================================================
# LE OUI/NON — LE VIEWMODEL
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module .\BaseViewModel.psm1

# La plus petite boîte : un titre, une question, la ligne rouge quand il y en
# a une. CONFIRM rend oui, la porte de fermeture porte la réponse.
class ConfirmViewModel : BaseViewModel {
    [string]$Title = "WSL Stack"
    [string]$Question = ""
    [string]$Danger = ""
    [object]$Result = $null
    [System.Windows.Input.ICommand]$ConfirmCommand

    ConfirmViewModel([string]$title, [string]$question, [string]$danger) {
        $this.Title = "$title"
        $this.Question = "$question"
        $this.Danger = "$danger"
        $this.ConfirmCommand = $this.NewCommand({ param($vm) $vm.Confirm() })
    }

    [void] Confirm() {
        $this.Result = $true
        $this.RequestClose()
    }
}
