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
    [string]$Miss = ""
    [string]$Error = ""

    BrowsePresenter([InstanceService]$service, [string]$viewsRoot, [string]$viewType, [object[]]$liveActions, [object]$registerAction, [object]$unregisterAction, [object[]]$archiveActions) : base($viewsRoot, $viewType, "Fleet") {
        $this.Service = $service
        $this.LiveActions = $liveActions
        $this.RegisterAction = $registerAction
        $this.UnregisterAction = $unregisterAction
        $this.ArchiveActions = $archiveActions
    }

    [object] AskInstances() {
        $this.Miss = ""
        $this.Error = ""
        $view = $this.GetView("Browse")
        try {
            $rows = @($this.Service.GetAll())
            $running = @($this.Service.GetRunningNames())
            $orphans = @($this.Service.GetOrphans())
        } catch {
            $this.ShowFailure($_.Exception.Message)
            $this.Miss = "failure"
            $this.Error = $_.Exception.Message
            return $null
        }
        $instances = @($rows | Where-Object { -not $_.IsArchive })
        if ($instances.Count -eq 0) {
            $view.ShowNoInstances($orphans)
            $this.Miss = "none"
            return $null
        }
        $picked = $view.PickInstance($instances, $orphans, $running)
        if (-not $picked) { $this.Miss = "cancelled"; return $null }
        return $picked
    }

    [object] AskArchives() {
        $this.Miss = ""
        $this.Error = ""
        $view = $this.GetView("Browse")
        try {
            $rows = @($this.Service.GetAll())
        } catch {
            $this.ShowFailure($_.Exception.Message)
            $this.Miss = "failure"
            $this.Error = $_.Exception.Message
            return $null
        }
        $archives = @($rows | Where-Object { $_.IsArchive })
        if ($archives.Count -eq 0) {
            $view.ShowNoArchives()
            $this.Miss = "none"
            return $null
        }
        $picked = $view.PickArchive($archives)
        if (-not $picked) { $this.Miss = "cancelled"; return $null }
        return $picked
    }

    [object] AskAction([object]$row) {
        $view = $this.GetView("Browse")
        if ($row.IsArchive) {
            return $view.PickAction("Availables actions for '$($row.Name)'", $this.ArchiveActions)
        }
        $docker = if ("$($row.Docker)" -eq "yes") { $this.UnregisterAction } else { $this.RegisterAction }
        $actions = @()
        foreach ($item in @($this.LiveActions)) {
            if ("$($item.Key)" -eq "unregister") { $actions += $docker }
            $actions += $item
        }
        return $view.PickAction("Availables actions for '$($row.Name)'", $actions)
    }
}
