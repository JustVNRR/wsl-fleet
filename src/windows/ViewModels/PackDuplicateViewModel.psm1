using module .\BaseViewModel.psm1

class PackDuplicateViewModel : BaseViewModel {
    hidden [object[]]$_taken = @()

    [string]$Lead = ""
    [string]$Name = ""
    [string]$Description = ""
    [string]$NameError = ""
    [object]$Result = $null
    [System.Windows.Input.ICommand]$ConfirmCommand

    PackDuplicateViewModel([string]$source, [string]$blurb, [string[]]$taken) {
        $this._taken = @($taken)
        $this.Lead = ("Duplicate the pack '$source'").ToUpperInvariant()
        $this.Name = "$source-copy"
        $this.Description = "$blurb"

        $this.ConfirmCommand = $this.NewCommand({ param($vm) $vm.Confirm() })
    }

    [void] SetName([string]$value) {
        if ($this.Name -cne "$value") {
            $this.Name = "$value"
            $this.OnPropertyChanged("Name")
        }
    }

    [void] SetDescription([string]$value) {
        if ($this.Description -cne "$value") {
            $this.Description = "$value"
            $this.OnPropertyChanged("Description")
        }
    }

    [void] Confirm() {
        $chosen = "$($this.Name)".Trim()
        $problem = ""
        if ($chosen -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*$') {
            $problem = "Letters, digits, '.', '_' and '-' only, starting with a letter or a digit."
        } elseif (@($this._taken | Where-Object { $_ -eq $chosen }).Count -gt 0) {
            $problem = "A pack named '$chosen' already exists."
        }
        if ($problem) {
            $this.NameError = $problem
            $this.OnPropertyChanged("NameError")
            return
        }
        $this.Result = [PSCustomObject]@{ Name = $chosen; Description = "$($this.Description)".Trim() }
        $this.RequestClose()
    }
}
