# ==============================================================================
# L'ARCHIVE — LE VIEWMODEL
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout lui-même ce qu'il
# tire.
using module .\BaseViewModel.psm1
using module ..\Dto\InstanceDto.psm1

# La porte de l'archive : l'arrêt se dit toujours (la phrase couvre les deux
# cas), le nom de l'archive ne se demande pas (XX devient XX_archive : la
# règle du modèle), et la ligne de l'écrasement se lit de l'index reçu.
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
