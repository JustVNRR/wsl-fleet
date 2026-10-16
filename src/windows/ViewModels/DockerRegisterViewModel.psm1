using module .\BaseViewModel.psm1

class DockerRegisterViewModel : BaseViewModel {

    hidden [string]$_name = ""
    [string]$Lead = ""
    [bool]$Restart = $true
    [object]$Result = $null
    [System.Windows.Input.ICommand]$ConfirmCommand

    DockerRegisterViewModel([string]$name, [string]$state) {
        $this._name = "$name"
        if ("$state" -eq "yes") {
            $this.Lead = ("Unregister '$name' from Docker Desktop?").ToUpperInvariant()
        } else {
            $this.Lead = ("Register '$name' with Docker Desktop?").ToUpperInvariant()
        }
        $this.ConfirmCommand = $this.NewCommand({ param($vm) $vm.Confirm() })
    }

    [void] SetRestart([bool]$value) {
        if ($this.Restart -ne $value) {
            $this.Restart = $value
            $this.OnPropertyChanged("Restart")
        }
    }

    [void] Confirm() {
        $this.Result = [PSCustomObject]@{ Name = $this._name; Restart = $this.Restart }
        $this.RequestClose()
    }
}
