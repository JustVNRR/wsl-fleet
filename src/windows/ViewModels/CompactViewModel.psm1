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
    hidden [string]$_lead = ""
    hidden [bool]$_archiveFirst = $false
    [object]$Result = $null
    [System.Windows.Input.ICommand]$ConfirmCommand

    CompactViewModel([string]$name) {
        $this._name = "$name"
        $this._lead = "Compacting '$name'."

        $this.AddProperty("Lead", { return $this._lead }, { param($value) })
        $this.AddProperty("ArchiveFirst", { return $this._archiveFirst }, {
            param($value)
            if ($this._archiveFirst -ne [bool]$value) { $this._archiveFirst = [bool]$value; $this.OnPropertyChanged("ArchiveFirst") }
        })

        $this.ConfirmCommand = $this.NewCommand({ param($vm) $vm.Confirm() })
    }

    [void] Confirm() {
        $dto = [CompactDto]::new()
        $dto.InstanceName = $this._name
        $dto.ArchiveFirst = $this._archiveFirst
        $this.Result = $dto
        $this.OnPropertyChanged("Done")
    }
}
