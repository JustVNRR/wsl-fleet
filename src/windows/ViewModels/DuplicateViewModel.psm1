# ==============================================================================
# LA COPIE — LE VIEWMODEL
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout lui-même ce qu'il
# tire.
using module .\BaseViewModel.psm1
using module ..\Dto\InstanceDto.psm1

# La copie : la phrase, l'avertissement d'arrêt (la liste ne porte plus
# l'état — il se dit toujours), le nom de la copie — celui de la source
# prérempli avec « -copy » derrière — et la vérification vivante du nom :
# vide, la forme, c'est tout. Le nom pris, lui, n'est pas su ici : le moteur
# refuse pour de vrai quand la course part, et le rapport le dira — la boîte
# avertit, elle ne verrouille pas.
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
        $this.Lead = "Copy '$source'."
        $this.Name = "$source-copy"

        $this.ConfirmCommand = $this.NewCommand({ param($vm) $vm.Confirm() }, { param($vm) $vm.CanConfirm() })
        $this.ValidateName()
    }

    # Le lien XAML est à sens unique : la vue relaie la saisie ici.
    [void] SetName([string]$value) {
        if ($this.Name -cne "$value") {
            $this.Name = "$value"
            $this.OnPropertyChanged("Name")
            $this.ValidateName()
        }
    }

    # La règle des noms d'instance, la même partout : la forme vérifiée en
    # direct sous la boîte.
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
        # $copyName : une locale ne peut pas porter le nom d'une propriété
        # réelle (mesuré au parse).
        $copyName = "$($this.Name)".Trim()
        if (-not $copyName) { return }
        $dto = [DuplicateDto]::new()
        $dto.SourceName = $this._source
        $dto.CopyName = $copyName
        $this.Result = $dto
        $this.RequestClose()
    }
}
