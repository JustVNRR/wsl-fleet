# ==============================================================================
# LA RESTAURATION — LE VIEWMODEL
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout lui-même ce qu'il
# tire.
using module .\BaseViewModel.psm1
using module ..\Dto\InstanceDto.psm1

# La restauration : la phrase avec l'archive, et le nom que la nouvelle
# instance prend — l'archive préremplie, la ramener sous son nom étant la
# réponse usuelle. Un nom vide n'allume pas RESTORE.
class RestoreViewModel : BaseViewModel {
    hidden [string]$_archiveName = ""
    hidden [string]$_lead = ""
    hidden [string]$_name = ""
    [object]$Result = $null
    [System.Windows.Input.ICommand]$ConfirmCommand

    RestoreViewModel([string]$archiveName) {
        $this._archiveName = "$archiveName"
        $this._lead = "The archive '$archiveName' comes back as a new instance."
        $this._name = "$archiveName"

        $this.AddProperty("Lead", { return $this._lead }, { param($value) })
        $this.AddProperty("Name", { return $this._name }, {
            param($value)
            if ($this._name -ne "$value") {
                $this._name = "$value"
                $this.OnPropertyChanged("Name")
                $this.ConfirmCommand.RaiseCanExecuteChanged()
            }
        })

        $this.ConfirmCommand = $this.NewCommand({ param($vm) $vm.Confirm() }, { param($vm) $vm.CanConfirm() })
    }

    [bool] CanConfirm() {
        return [bool]("$($this._name)".Trim())
    }

    [void] Confirm() {
        $name = "$($this._name)".Trim()
        if (-not $name) { return }
        $dto = [RestoreDto]::new()
        $dto.ArchiveName = $this._archiveName
        $dto.InstanceName = $name
        $this.Result = $dto
        $this.OnPropertyChanged("Done")
    }
}
