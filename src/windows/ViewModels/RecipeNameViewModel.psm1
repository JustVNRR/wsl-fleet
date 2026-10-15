# ==============================================================================
# A RECIPE'S NAME - THE VIEWMODEL
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module .\BaseViewModel.psm1

# The + popup of the build form: one name, the rule, and APPLY closes with it
# - nothing is created here, the caller does the folder.
class RecipeNameViewModel : BaseViewModel {
    [string]$Lead = "Create a recipe"
    [string]$Name = ""
    [string]$NameError = ""
    [object]$Result = $null
    [System.Windows.Input.ICommand]$ConfirmCommand

    RecipeNameViewModel() {
        $this.ConfirmCommand = $this.NewCommand({ param($vm) $vm.Confirm() })
    }

    # The XAML links are one-way: the view relays every keystroke here.
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
