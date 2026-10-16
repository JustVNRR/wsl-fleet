using module ..\ActionResult.psm1
using module ..\BasePresenter.psm1
using module ..\..\Services\InstanceService.psm1

class DeleteArchivePresenter : BasePresenter {
    hidden [InstanceService]$Service

    DeleteArchivePresenter([InstanceService]$service, [string]$viewsRoot, [string]$viewType) : base($viewsRoot, $viewType, "Instance") {
        $this.Service = $service
    }

    [ActionResult] Run([string]$target) {
        $view = $this.GetView("DeleteArchive")
        if ([string]::IsNullOrWhiteSpace($target)) {
            $view.ShowNoName()
            return [ActionResult]::Nok("DeleteArchive : no name")
        }

        $view.ShowDeleting($target)
        try {
            $response = $this.Service.DeleteArchive($target)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("DeleteArchive : $target - $($_.Exception.Message)")
        }
        $view.Show($response)
        return [ActionResult]::Ok("DeleteArchive : $target")
    }
}
