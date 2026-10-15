# ==============================================================================
# DOCKER REGISTER — THE VIEWMODEL
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module .\BaseViewModel.psm1

# The Docker Desktop door: the sentence follows the row's state - register or
# take out - the restart box is on by default with its price written beside
# it, and APPLY closes with the name and the box. The main window makes the
# gesture.
class DockerRegisterViewModel : BaseViewModel {
    hidden [string]$_name = ""
    [string]$Lead = ""
    [bool]$Restart = $true
    [object]$Result = $null
    [System.Windows.Input.ICommand]$ConfirmCommand

    DockerRegisterViewModel([string]$name, [string]$state) {
        $this._name = "$name"
        if ("$state" -eq "yes") {
            $this.Lead = "Unregister '$name' from Docker Desktop?"
        } else {
            $this.Lead = "Register '$name' with Docker Desktop?"
        }
        $this.ConfirmCommand = $this.NewCommand({ param($vm) $vm.Confirm() })
    }

    # The XAML link is one-way: the view relays the box here.
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
