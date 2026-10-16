using module .\BaseViewModel.psm1

class RecipeNameViewModel : BaseViewModel {
    [string]$Lead = "Create a recipe"
    [string]$Name = ""
    [string]$NameError = ""
    [object]$Result = $null
    [System.Windows.Input.ICommand]$ConfirmCommand

    RecipeNameViewModel() {
        $this.ConfirmCommand = $this.NewCommand({ param($vm) $vm.Confirm() })
    }

    [void] SetName([string]$value) {
        if ($this.Name -cne "$value") {
            $this.Name = "$value"
            $this.OnPropertyChanged("Name")
        }
    }

    [void] Confirm() {
        $chosen = "$($this.Name)".Trim()
        if ($chosen -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*$') {
            $this.NameError = "Letters, digits, '.', '_' and '-' only, starting with a letter or a digit."
            $this.OnPropertyChanged("NameError")
            return
        }
        $this.Result = $chosen
        $this.RequestClose()
    }
}
