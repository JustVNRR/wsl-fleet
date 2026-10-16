using module ..\ActionResult.psm1
using module ..\BasePresenter.psm1
using module .\shared\SelectInstancePresenter.psm1
using module ..\..\Services\InstanceService.psm1
using module ..\..\Dtos\InstanceDto.psm1

class CompactPresenter : BasePresenter {

    hidden [InstanceService]$Service
    [SelectInstancePresenter]$Picker

    CompactPresenter([InstanceService]$service, [string]$viewsRoot, [string]$viewType) : base($viewsRoot, $viewType, "Instance") {
        $this.Service = $service
        $this.Picker = [SelectInstancePresenter]::new($viewsRoot, $viewType)
    }

    [ActionResult] Run([string]$target) {
        try {
            $rows = @($this.Service.GetAll())
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Compact : $($_.Exception.Message)")
        }

        $name = $this.Picker.Pick($target, $rows)
        if (-not $name) {
            if ($this.Picker.Miss -eq "none") { return [ActionResult]::Nok("Compact : no instance") }
            return [ActionResult]::Ok("Compact : cancelled")
        }

        $view = $this.GetView("Compact")
        $view.ShowBeforeQuestions()
        $archiveFirst = $view.Confirm("Archive it first?", $false)
        if ($null -eq $archiveFirst) {
            $view.ShowCancelled("modified")
            return [ActionResult]::Ok("Compact : cancelled")
        }
        if (-not $archiveFirst) {
            $view.ShowNoArchive()
        } elseif (@($rows | Where-Object { $_.IsArchive -and "$($_.Name)" -eq "$($name)_archive" }).Count -gt 0) {
            $view.ShowReplacingArchive($name)
        }
        $view.ShowCompacting($name, $archiveFirst)

        $dto = [CompactDto]::new()
        $dto.InstanceName = $name
        $dto.ArchiveFirst = [bool]$archiveFirst

        try {
            $response = $this.Service.Compact($dto)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Compact : $name - $($_.Exception.Message)")
        }
        $view.Show($response)
        return [ActionResult]::Ok("Compact : $name")
    }
}
