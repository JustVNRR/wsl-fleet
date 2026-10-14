# ==============================================================================
# LA COMPACITÉ — LE VIEWMODEL
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout lui-même ce qu'il
# tire.
using module .\BaseViewModel.psm1
using module ..\Dto\InstanceDto.psm1

# La porte de la compacité : la phrase avec le nom, l'avertissement d'arrêt,
# et la même case « archiver d'abord » que la corbeille.
class CompactViewModel : BaseViewModel {
    hidden [string]$_name = ""
    [string]$Lead = ""
    [bool]$ArchiveFirst = $false
    [object]$Result = $null
    [System.Windows.Input.ICommand]$ConfirmCommand

    CompactViewModel([string]$name) {
        $this._name = "$name"
        $this.Lead = "Compacting '$name'."

        $this.ConfirmCommand = $this.NewCommand({ param($vm) $vm.Confirm() })
    }

    # Le lien XAML est à sens unique : la vue relaie la bascule ici.
    [void] SetArchiveFirst([bool]$value) {
        if ($this.ArchiveFirst -ne $value) {
            $this.ArchiveFirst = $value
            $this.OnPropertyChanged("ArchiveFirst")
        }
    }

    [void] Confirm() {
        $dto = [CompactDto]::new()
        $dto.InstanceName = $this._name
        $dto.ArchiveFirst = $this.ArchiveFirst
        $this.Result = $dto
        $this.OnPropertyChanged("Done")
    }
}
