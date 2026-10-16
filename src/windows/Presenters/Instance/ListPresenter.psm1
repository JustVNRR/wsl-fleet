using module ..\ActionResult.psm1
using module ..\BasePresenter.psm1
using module ..\..\Services\InstanceService.psm1
using module ..\..\Dtos\InstanceDto.psm1

class ListPresenter : BasePresenter {

    hidden [InstanceService]$Service

    ListPresenter([InstanceService]$service, [string]$viewsRoot, [string]$viewType) : base($viewsRoot, $viewType, "Instance") {
        $this.Service = $service
    }

    [ActionResult] Run() {
        $view = $this.GetView("List")
        try {
            $rows = @($this.Service.GetAll())
            $orphans = @($this.Service.GetOrphans())
            $running = @($this.Service.GetRunningNames())
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("List : $($_.Exception.Message)")
        }
        $index = [ListResponseDto]::new()
        $index.Rows = @($rows)
        $index.Orphans = @($orphans)
        $index.Running = @($running)
        $view.Show($index)
        if (($rows.Count + $orphans.Count) -eq 0) { return [ActionResult]::Nok("List : none") }
        return [ActionResult]::Ok("List : $($rows.Count + $orphans.Count) row(s)")
    }
}
