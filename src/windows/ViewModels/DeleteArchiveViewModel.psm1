# ==============================================================================
# LA CORBEILLE D'ARCHIVE — LE VIEWMODEL
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout lui-même ce qu'il
# tire.
using module .\BaseViewModel.psm1
# La porte de la suppression d'archive : la phrase avec le nom, et le nom
# retapé — DELETE ne s'éveille que sur lui, case ignorée.
# Confirm rend le nom confirmé — la fenêtre principale en fait le geste.
class DeleteArchiveViewModel : BaseViewModel {
    hidden [string]$_archiveName = ""
    [string]$Lead = ""
    [string]$Typed = ""
    [object]$Result = $null
    [System.Windows.Input.ICommand]$ConfirmCommand

    DeleteArchiveViewModel([string]$archiveName) {
        $this._archiveName = "$archiveName"
        $this.Lead = ("The archive '$archiveName' will be deleted and will not be restorable again.").ToUpperInvariant()

        $this.ConfirmCommand = $this.NewCommand({ param($vm) $vm.Confirm() }, { param($vm) $vm.CanConfirm() })
    }

    # Le lien XAML est à sens unique : la vue relaie la saisie ici.
    [void] SetTyped([string]$value) {
        if ($this.Typed -ne "$value") {
            $this.Typed = "$value"
            $this.OnPropertyChanged("Typed")
            $this.ConfirmCommand.RaiseCanExecuteChanged()
        }
    }

    [bool] CanConfirm() {
        # -eq : the name; the case does not count.
        return ("$($this.Typed)" -eq $this._archiveName)
    }

    [void] Confirm() {
        if (-not $this.CanConfirm()) { return }
        $this.Result = $this._archiveName
        $this.RequestClose()
    }
}
