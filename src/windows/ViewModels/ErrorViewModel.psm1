# ==============================================================================
# THE ERROR BOX — THE VIEWMODEL
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module .\BaseViewModel.psm1
using module ..\Dtos\InstanceDto.psm1

# The error box: one entry of the log, shown - its words, and when and at
# which level they came. A single OK closes it.
class ErrorViewModel : BaseViewModel {
    [string]$Lead = ""
    [string]$Stamp = ""

    ErrorViewModel([LogEntryDto]$entry) {
        $this.Lead = "$($entry.Message)"
        $this.Stamp = "$($entry.When.ToString('yyyy-MM-dd HH:mm:ss')) [$($entry.Level)]"
    }
}
