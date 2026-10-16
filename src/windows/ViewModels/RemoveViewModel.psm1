# ==============================================================================
# LA DESTRUCTION — LE VIEWMODEL
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout lui-même ce qu'il
# tire.
using module .\BaseViewModel.psm1
using module ..\Dtos\InstanceDto.psm1

# La porte de la destruction : la phrase avec le nom, l'écho de ce qui part,
# la case « archiver d'abord », et le nom exact retapé — REMOVE ne s'éveille
# que sur lui — case ignorée.
class RemoveViewModel : BaseViewModel {
    hidden [string]$_name = ""
    [string]$Lead = ""
    [string]$Typed = ""
    [bool]$ArchiveFirst = $false
    [object]$Result = $null
    [System.Windows.Input.ICommand]$ConfirmCommand

    RemoveViewModel([string]$name) {
        $this._name = "$name"
        $this.Lead = ("The WSL distribution '$name' and ALL its data will be deleted.").ToUpperInvariant()

        $this.ConfirmCommand = $this.NewCommand({ param($vm) $vm.Confirm() }, { param($vm) $vm.CanConfirm() })
    }

    # Les liens XAML sont à sens unique : la vue relaie saisies et bascules.
    [void] SetTyped([string]$value) {
        if ($this.Typed -ne "$value") {
            $this.Typed = "$value"
            $this.OnPropertyChanged("Typed")
            $this.ConfirmCommand.RaiseCanExecuteChanged()
        }
    }

    [void] SetArchiveFirst([bool]$value) {
        if ($this.ArchiveFirst -ne $value) {
            $this.ArchiveFirst = $value
            $this.OnPropertyChanged("ArchiveFirst")
        }
    }

    [bool] CanConfirm() {
        # -eq : the name; the case does not count.
        return ("$($this.Typed)" -eq $this._name)
    }

    [void] Confirm() {
        if (-not $this.CanConfirm()) { return }
        $dto = [RemoveDto]::new()
        $dto.InstanceName = $this._name
        $dto.ArchiveFirst = $this.ArchiveFirst
        $this.Result = $dto
        $this.RequestClose()
    }
}
