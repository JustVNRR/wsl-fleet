using module ..\ActionResult.psm1
using module ..\BasePresenter.psm1
using module .\shared\SelectInstancePresenter.psm1
using module ..\..\Services\InstanceService.psm1
using module ..\..\Dtos\InstanceDto.psm1

class DuplicatePresenter : BasePresenter {

    hidden [InstanceService]$Service
    [SelectInstancePresenter]$Picker

    DuplicatePresenter([InstanceService]$service, [string]$viewsRoot, [string]$viewType) : base($viewsRoot, $viewType, "Instance") {
        $this.Service = $service
        $this.Picker = [SelectInstancePresenter]::new($viewsRoot, $viewType)
    }

    [ActionResult] Run([string]$target) {
        try {
            $rows = @($this.Service.GetAll())
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Duplicate : $($_.Exception.Message)")
        }

        $source = $this.Picker.Pick($target, $rows)
        if (-not $source) {
            if ($this.Picker.Miss -eq "none") { return [ActionResult]::Nok("Duplicate : no instance") }
            return [ActionResult]::Ok("Duplicate : cancelled")
        }

        $view = $this.GetView("Duplicate")
        $copy = ""
        while ($true) {
            $answer = $view.AskCopyName()
            if (-not $answer) {
                $view.ShowCancelled("created")
                return [ActionResult]::Ok("Duplicate : cancelled")
            }
            if ($answer -match '^[A-Za-z0-9][A-Za-z0-9_.-]*$') { $copy = $answer; break }
            $view.ShowNameHint()
        }

        $view.ShowDiskWarning($source)
        if (-not $view.Confirm("Continue?", $false)) {
            $view.ShowCancelled("created")
            return [ActionResult]::Ok("Duplicate : cancelled")
        }
        $view.ShowDuplicating($source, $copy)

        $dto = [DuplicateDto]::new()
        $dto.SourceName = $source
        $dto.CopyName = $copy

        try {
            $response = $this.Service.Duplicate($dto)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Duplicate : $source - $($_.Exception.Message)")
        }
        $view.Show($response)
        return [ActionResult]::Ok("Duplicate : $copy")
    }
}
