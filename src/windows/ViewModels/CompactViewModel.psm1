using module .\BaseViewModel.psm1
using module ..\Dtos\InstanceDto.psm1

class CompactViewModel : BaseViewModel {

    hidden [string]$_name = ""
    [string]$Lead = ""
    [bool]$ArchiveFirst = $false
    [object]$Result = $null
    [System.Windows.Input.ICommand]$ConfirmCommand

    CompactViewModel([string]$name) {
        $this._name = "$name"
        $this.Lead = ("Compacting '$name'.").ToUpperInvariant()

        $this.ConfirmCommand = $this.NewCommand({ param($vm) $vm.Confirm() })
    }

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
        $this.RequestClose()
    }
}
