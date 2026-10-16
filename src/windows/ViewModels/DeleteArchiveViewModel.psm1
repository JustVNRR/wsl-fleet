using module .\BaseViewModel.psm1
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

    [void] SetTyped([string]$value) {
        if ($this.Typed -ne "$value") {
            $this.Typed = "$value"
            $this.OnPropertyChanged("Typed")
            $this.ConfirmCommand.RaiseCanExecuteChanged()
        }
    }

    [bool] CanConfirm() {
        return ("$($this.Typed)" -eq $this._archiveName)
    }

    [void] Confirm() {
        if (-not $this.CanConfirm()) { return }
        $this.Result = $this._archiveName
        $this.RequestClose()
    }
}
