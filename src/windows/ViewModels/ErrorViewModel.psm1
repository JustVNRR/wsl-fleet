using module .\BaseViewModel.psm1
using module ..\Dtos\InstanceDto.psm1

class ErrorViewModel : BaseViewModel {

    [string]$Lead = ""
    [string]$Stamp = ""

    ErrorViewModel([LogEntryDto]$entry) {
        $this.Lead = "$($entry.Message)"
        $this.Stamp = "$($entry.When.ToString('yyyy-MM-dd HH:mm:ss')) [$($entry.Level)]"
    }
}
