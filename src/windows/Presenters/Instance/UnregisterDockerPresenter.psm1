using module ..\ActionResult.psm1
using module ..\BasePresenter.psm1
using module .\shared\SelectInstancePresenter.psm1
using module ..\..\Services\InstanceService.psm1
using module ..\..\Dtos\InstanceDto.psm1

class UnregisterDockerPresenter : BasePresenter {

    hidden [InstanceService]$Service
    [SelectInstancePresenter]$Picker

    UnregisterDockerPresenter([InstanceService]$service, [string]$viewsRoot, [string]$viewType) : base($viewsRoot, $viewType, "Instance") {
        $this.Service = $service
        $this.Picker = [SelectInstancePresenter]::new($viewsRoot, $viewType)
    }

    [ActionResult] Run([string]$target) {
        try {
            $rows = @($this.Service.GetAll())
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("UnregisterDocker : $($_.Exception.Message)")
        }

        $live = @($rows | Where-Object { -not $_.IsArchive })
        $candidates = @($live | Where-Object { "$($_.Docker)" -eq "yes" })

        $view = $this.GetView("UnregisterDocker")

        $name = ""
        if ($target) {
            $row = @($live | Where-Object { "$($_.Name)" -ceq "$target" })
            if ($row.Count -eq 0) {
                $this.ShowFailure("'$target' is not an instance of this machine.")
                return [ActionResult]::Nok("UnregisterDocker : no instance")
            }
            if ("$($row[0].Docker)" -eq "no") {
                $view.ShowNotRegistered("$target")
                return [ActionResult]::Nok("UnregisterDocker : $target")
            }
            if ("$($row[0].Docker)" -ne "yes") {
                $view.ShowSettingsUnreadable()
                return [ActionResult]::Nok("UnregisterDocker : $target")
            }
            $name = "$target"
        } else {
            if ($candidates.Count -eq 0) {
                if ($live.Count -gt 0 -and @($live | Where-Object { "$($_.Docker)" -ne "unknown" }).Count -eq 0) {
                    $view.ShowSettingsUnreadable()
                } else {
                    $view.ShowNoCandidates()
                }
                return [ActionResult]::Nok("UnregisterDocker : none to unregister")
            }
            $name = $this.Picker.Pick("", $candidates)
            if (-not $name) { return [ActionResult]::Ok("UnregisterDocker : cancelled") }
        }

        if (-not $view.AskUnregister($name)) {
            $view.ShowCancelled("modified")
            return [ActionResult]::Ok("UnregisterDocker : cancelled")
        }
        $restart = $view.AskRestartDocker()

        $dto = [UnregisterDockerDto]::new()
        $dto.InstanceName = $name
        $dto.Restart = $restart

        try {
            $response = $this.Service.UnregisterDocker($dto)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("UnregisterDocker : $name - $($_.Exception.Message)")
        }
        $view.Show($response)
        return [ActionResult]::Ok("UnregisterDocker : $name")
    }
}
