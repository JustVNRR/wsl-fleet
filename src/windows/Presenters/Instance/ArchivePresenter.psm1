using module ..\ActionResult.psm1
using module ..\BasePresenter.psm1
using module .\shared\SelectInstancePresenter.psm1
using module ..\..\Services\InstanceService.psm1
using module ..\..\Dtos\InstanceDto.psm1

class ArchivePresenter : BasePresenter {
    hidden [InstanceService]$Service

    [SelectInstancePresenter]$Picker

    ArchivePresenter([InstanceService]$service, [string]$viewsRoot, [string]$viewType) : base($viewsRoot, $viewType, "Instance") {
        $this.Service = $service
        $this.Picker = [SelectInstancePresenter]::new($viewsRoot, $viewType)
    }

    [ActionResult] Run([string]$target) {
        try {
            $rows = @($this.Service.GetAll())
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Archive : $($_.Exception.Message)")
        }

        $name = $this.Picker.Pick($target, $rows)
        if (-not $name) {
            if ($this.Picker.Miss -eq "none") { return [ActionResult]::Nok("Archive : no instance") }
            return [ActionResult]::Ok("Archive : cancelled")
        }

        $view = $this.GetView("Archive")
        $view.ShowStopWarning($name)
        if (-not $view.Confirm("Continue?", $false)) {
            $view.ShowCancelled("modified")
            return [ActionResult]::Ok("Archive : cancelled")
        }

        $archiveName = "$($name)_archive"
        if (@($rows | Where-Object { $_.IsArchive -and "$($_.Name)" -eq $archiveName }).Count -gt 0) {
            $view.ShowReplacing($archiveName)
        }
        $view.ShowBackingUp($name)

        $dto = [ArchiveDto]::new()
        $dto.InstanceName = $name
        $dto.Format = "tar.gz"
        $dto.Permit = $true

        try {
            $response = $this.Service.Archive($dto)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Archive : $name - $($_.Exception.Message)")
        }
        $view.Show($response)
        return [ActionResult]::Ok("Archive : $name")
    }
}
