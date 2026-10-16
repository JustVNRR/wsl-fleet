using module .\BaseViewModel.psm1
using module ..\Dtos\InstanceDto.psm1

class RestoreViewModel : BaseViewModel {
    hidden [string]$_archiveName = ""
    [string]$Lead = ""
    [string]$Name = ""
    [object]$Result = $null
    [System.Windows.Input.ICommand]$ConfirmCommand

    RestoreViewModel([string]$archiveName) {
        $this._archiveName = "$archiveName"
        $this.Lead = ("The archive '$archiveName' comes back as a new instance.").ToUpperInvariant()
        $this.Name = "$archiveName"

        $this.ConfirmCommand = $this.NewCommand({ param($vm) $vm.Confirm() }, { param($vm) $vm.CanConfirm() })
    }

    [void] SetName([string]$value) {
        if ($this.Name -cne "$value") {
            $this.Name = "$value"
            $this.OnPropertyChanged("Name")
            $this.ConfirmCommand.RaiseCanExecuteChanged()
        }
    }

    [bool] CanConfirm() {
        return [bool]("$($this.Name)".Trim())
    }

    [void] Confirm() {
        $wanted = "$($this.Name)".Trim()
        if (-not $wanted) { return }
        $dto = [RestoreDto]::new()
        $dto.ArchiveName = $this._archiveName
        $dto.InstanceName = $wanted
        $this.Result = $dto
        $this.RequestClose()
    }
}
