using module ..\ActionResult.psm1
using module ..\BasePresenter.psm1
using module ..\..\Services\InstanceService.psm1
using module ..\..\Dtos\InstanceDto.psm1

class BrowsePresenter : BasePresenter {

    hidden [InstanceService]$Service
    hidden [object[]]$LiveActions
    hidden [object]$RegisterAction
    hidden [object]$UnregisterAction
    hidden [object[]]$ArchiveActions

    BrowsePresenter([InstanceService]$service, [string]$viewsRoot, [string]$viewType, [object[]]$liveActions, [object]$registerAction, [object]$unregisterAction, [object[]]$archiveActions) : base($viewsRoot, $viewType, "Fleet") {
        $this.Service = $service
        $this.LiveActions = $liveActions
        $this.RegisterAction = $registerAction
        $this.UnregisterAction = $unregisterAction
        $this.ArchiveActions = $archiveActions
    }

    [ActionResult] Run([hashtable]$Presenters, [string]$kind) {
        $view = $this.GetView("Browse")
        try {
            $rows = @($this.Service.GetAll())
            $running = @($this.Service.GetRunningNames())
            $orphans = @($this.Service.GetOrphans())
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Browse : $($_.Exception.Message)")
        }

        if ($kind -eq "archives") {
            $archives = @($rows | Where-Object { $_.IsArchive })
            if ($archives.Count -eq 0) {
                $view.ShowNoArchives()
                return [ActionResult]::Nok("Archives : none")
            }
            $picked = $view.PickArchive($archives)
            if (-not $picked) { return [ActionResult]::Ok("Archives : cancelled") }
            $action = $view.PickAction("What to do with '$($picked.Name)'", $this.ArchiveActions)
            if (-not $action) { return [ActionResult]::Ok("Archives : cancelled") }
            return (& $action.Action "$($picked.Name)" $Presenters)
        }

        $instances = @($rows | Where-Object { -not $_.IsArchive })
        if ($instances.Count -eq 0) {
            $view.ShowNoInstances($orphans)
            return [ActionResult]::Nok("Instances : none")
        }
        $picked = $view.PickInstance($instances, $orphans, $running)
        if (-not $picked) { return [ActionResult]::Ok("Instances : cancelled") }

        $docker = if ("$($picked.Docker)" -eq "yes") { $this.UnregisterAction } else { $this.RegisterAction }
        $actions = @()
        foreach ($item in @($this.LiveActions)) {
            if ("$($item.Key)" -eq "unregister") { $actions += $docker }
            $actions += $item
        }
        $action = $view.PickAction("What to do with '$($picked.Name)'", $actions)
        if (-not $action) { return [ActionResult]::Ok("Instances : cancelled") }
        return (& $action.Action "$($picked.Name)" $Presenters)
    }
}
