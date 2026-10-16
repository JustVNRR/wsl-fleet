# ==============================================================================
# LA QUESTION DE LA RACINE — LE VIEWMODEL
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module .\BaseViewModel.psm1
using module ..\Tools\Helpers.psm1

# La question du déplacement de la racine : l'avertissement, le dossier
# d'arrivée, et la garde du service — dite ICI, la boîte reste ouverte et
# montre pourquoi ; rien ne part pour un chemin impossible. CONFIRM rend le
# dossier, ou rien.
class RootMoveViewModel : BaseViewModel {
    hidden [string]$_current = ""

    [string]$Lead = ""
    [string]$Warning = ""
    [string]$NewRoot = ""
    [object]$Result = $null
    [System.Windows.Input.ICommand]$ConfirmCommand

    RootMoveViewModel([string]$current) {
        $this._current = "$($current)".TrimEnd('\')
        $this.Lead = ("Move the fleet from '$current'").ToUpperInvariant()
        $this.Warning = "Every instance will be archived and unregistered before migration."
        $this.NewRoot = "$current"

        $this.ConfirmCommand = $this.NewCommand({ param($vm) $vm.Confirm() })
    }

    # Le lien XAML est à sens unique : la vue relaie la saisie ici.
    [void] SetNewRoot([string]$value) {
        if ($this.NewRoot -cne "$value") {
            $this.NewRoot = "$value"
            $this.OnPropertyChanged("NewRoot")
        }
    }

    [void] Confirm() {
        $chosen = "$($this.NewRoot)".Trim().Trim('"').TrimEnd('\')
        if (-not $chosen -or $chosen -eq $this._current) { return }
        $problem = Test-FleetTarget $chosen
        if ($problem) {
            $this.Warning = $problem
            $this.OnPropertyChanged("Warning")
            return
        }
        $this.Result = $chosen
        $this.RequestClose()
    }
}
