using module .\BaseViewModel.psm1
using module ..\Dtos\InstanceDto.psm1

class ArchiveViewModel : BaseViewModel {
    hidden [string]$_name = ""
    [string]$Lead = ""
    [bool]$TakenVisible = $false
    [object]$Result = $null
    [System.Windows.Input.ICommand]$ConfirmCommand

    ArchiveViewModel([string]$name, [object[]]$rows) {
        $this._name = "$name"
        $this.Lead = ("Back up '$name' as '${name}_archive'.").ToUpperInvariant()
        $taken = @($rows | Where-Object { $_.IsArchive -and "$($_.Name)" -eq "${name}_archive" })
        $this.TakenVisible = ($taken.Count -gt 0)

        $this.ConfirmCommand = $this.NewCommand({ param($vm) $vm.Confirm() })
    }

    [void] Confirm() {
        $dto = [ArchiveDto]::new()
        $dto.InstanceName = $this._name
        $dto.Format = "tar.gz"
        $dto.Permit = $true
        $this.Result = $dto
        $this.RequestClose()
    }
}
