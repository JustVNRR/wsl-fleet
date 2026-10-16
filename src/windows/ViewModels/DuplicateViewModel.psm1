using module .\BaseViewModel.psm1
using module ..\Dtos\InstanceDto.psm1

class DuplicateViewModel : BaseViewModel {
    hidden [string]$_source = ""
    [string]$Lead = ""
    [string]$Name = ""
    [string]$NameError = ""
    hidden [bool]$_nameOk = $false
    [object]$Result = $null
    [System.Windows.Input.ICommand]$ConfirmCommand

    DuplicateViewModel([string]$source) {
        $this._source = "$source"
        $this.Lead = ("Duplicate '$source'.").ToUpperInvariant()
        $this.Name = "$source-copy"

        $this.ConfirmCommand = $this.NewCommand({ param($vm) $vm.Confirm() }, { param($vm) $vm.CanConfirm() })
        $this.ValidateName()
    }

    [void] SetName([string]$value) {
        if ($this.Name -cne "$value") {
            $this.Name = "$value"
            $this.OnPropertyChanged("Name")
            $this.ValidateName()
        }
    }

    [void] ValidateName() {
        $problem = ""
        $trimmed = "$($this.Name)".Trim()
        if (-not $trimmed) { $problem = "Give a name." }
        elseif ($trimmed -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*$') { $problem = "Letters, digits, '.', '_' and '-' only." }
        $this.NameError = $problem
        $this._nameOk = (-not $problem)
        $this.OnPropertyChanged("NameError")
        $this.ConfirmCommand.RaiseCanExecuteChanged()
    }

    [bool] CanConfirm() {
        return $this._nameOk
    }

    [void] Confirm() {
        $copyName = "$($this.Name)".Trim()
        if (-not $copyName) { return }
        $dto = [DuplicateDto]::new()
        $dto.SourceName = $this._source
        $dto.CopyName = $copyName
        $this.Result = $dto
        $this.RequestClose()
    }
}
