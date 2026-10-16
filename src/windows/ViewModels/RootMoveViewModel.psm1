using module .\BaseViewModel.psm1
using module ..\Tools\Helpers.psm1

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
