using module .\BaseViewModel.psm1

class ConfirmViewModel : BaseViewModel {

    [string]$Title = "Wsl Fleet"
    [string]$Question = ""
    [string]$Danger = ""
    [object]$Result = $null
    [System.Windows.Input.ICommand]$ConfirmCommand

    ConfirmViewModel([string]$title, [string]$question, [string]$danger) {
        $this.Title = "$title"
        $this.Question = "$question"
        $this.Danger = "$danger"
        $this.ConfirmCommand = $this.NewCommand({ param($vm) $vm.Confirm() })
    }

    [void] Confirm() {
        $this.Result = $true
        $this.RequestClose()
    }
}
