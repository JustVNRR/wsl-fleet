# ==============================================================================
# LA DESTRUCTION — LE VIEWMODEL
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout lui-même ce qu'il
# tire.
using module .\BaseViewModel.psm1
using module ..\Dto\InstanceDto.psm1

# La porte de la destruction : la phrase avec le nom, l'écho de ce qui part,
# la case « archiver d'abord », et le nom exact retapé — REMOVE ne s'éveille
# que sur lui, casse comprise (-ceq de la console).
class RemoveViewModel : BaseViewModel {
    hidden [string]$_name = ""
    hidden [string]$_lead = ""
    hidden [string]$_typed = ""
    hidden [bool]$_archiveFirst = $false
    [object]$Result = $null
    [System.Windows.Input.ICommand]$ConfirmCommand

    RemoveViewModel([string]$name) {
        $this._name = "$name"
        $this._lead = "The WSL distribution '$name' and ALL its data will be deleted."

        $this.AddProperty("Lead", { return $this._lead }, { param($value) })
        $this.AddProperty("Typed", { return $this._typed }, {
            param($value)
            # -cne : le champ se compare à la casse près en aval — un
            # changement de casse seule doit compter (mesuré à la fumée).
            if ($this._typed -cne "$value") {
                $this._typed = "$value"
                $this.OnPropertyChanged("Typed")
                $this.ConfirmCommand.RaiseCanExecuteChanged()
            }
        })
        $this.AddProperty("ArchiveFirst", { return $this._archiveFirst }, {
            param($value)
            if ($this._archiveFirst -ne [bool]$value) { $this._archiveFirst = [bool]$value; $this.OnPropertyChanged("ArchiveFirst") }
        })

        $this.ConfirmCommand = $this.NewCommand({ param($vm) $vm.Confirm() }, { param($vm) $vm.CanConfirm() })
    }

    [bool] CanConfirm() {
        # -ceq : le nom exact, casse comprise.
        return ("$($this._typed)" -ceq $this._name)
    }

    [void] Confirm() {
        if (-not $this.CanConfirm()) { return }
        $dto = [RemoveDto]::new()
        $dto.InstanceName = $this._name
        $dto.ArchiveFirst = $this._archiveFirst
        $this.Result = $dto
        $this.OnPropertyChanged("Done")
    }
}
