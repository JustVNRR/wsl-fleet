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
    [string]$Lead = ""
    [string]$Name = ""
    [object]$Result = $null
    [System.Windows.Input.ICommand]$ConfirmCommand

    RestoreViewModel([string]$archiveName) {
        $this._archiveName = "$archiveName"
        $this.Lead = ("The archive '$archiveName' comes back as a new instance.").ToUpperInvariant()
        $this.Name = "$archiveName"

        $this.ConfirmCommand = $this.NewCommand({ param($vm) $vm.Confirm() }, { param($vm) $vm.CanConfirm() })
    }

    # Le lien XAML est à sens unique : la vue relaie la saisie ici.
    [void] SetName([string]$value) {
        if ($this.Name -cne "$value") {
            $this.Name = "$value"
            $this.OnPropertyChanged("Name")
            $this.ConfirmCommand.RaiseCanExecuteChanged()
        }
    }

    [bool] CanConfirm() {
        return [bool]("$($this.Name)".Trim())
    }

    [void] Confirm() {
        # $wanted : une locale ne peut pas porter le nom d'une propriété
        # réelle (mesuré au parse).
        $wanted = "$($this.Name)".Trim()
        if (-not $wanted) { return }
        $dto = [RestoreDto]::new()
        $dto.ArchiveName = $this._archiveName
        $dto.InstanceName = $wanted
        $this.Result = $dto
        $this.RequestClose()
    }
}
