using module ..\ActionResult.psm1
using module ..\BasePresenter.psm1
using module ..\..\Services\InstanceService.psm1
using module ..\..\Dtos\InstanceDto.psm1

class RestorePresenter : BasePresenter {
    hidden [InstanceService]$Service

    RestorePresenter([InstanceService]$service, [string]$viewsRoot, [string]$viewType) : base($viewsRoot, $viewType, "Instance") {
        $this.Service = $service
    }

    [ActionResult] Run([string]$target) {
        $view = $this.GetView("Restore")

        $rows = @()
        try { $rows = @($this.Service.GetAll()) } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Restore : $($_.Exception.Message)")
        }

        $archiveName = $target
        if (-not $archiveName) {
            $archives = @($rows | Where-Object { $_.IsArchive })
            if ($archives.Count -eq 0) {
                $view.ShowNoArchives()
                return [ActionResult]::Nok("Restore : there are no archives")
            }
            $archiveName = $view.AskArchive($archives)
            if (-not $archiveName) {
                $view.ShowCancelled("created")
                return [ActionResult]::Ok("Restore : cancelled")
            }
        }

        $view.ShowRestoring($archiveName)
        $name = $view.AskNewName()
        if (-not $name) {
            $view.ShowCancelled("created")
            return [ActionResult]::Ok("Restore : cancelled")
        }

        $dto = [RestoreDto]::new()
        $dto.ArchiveName = $archiveName
        $dto.InstanceName = $name

        try {
            $response = $this.Service.Restore($dto)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Restore : $name - $($_.Exception.Message)")
        }
        $view.Show($response)
        return [ActionResult]::Ok("Restore : $name")
    }
}
