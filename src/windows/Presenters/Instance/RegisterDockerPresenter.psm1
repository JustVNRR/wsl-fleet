# ==============================================================================
# REGISTERDOCKER — THE PRESENTER
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\ActionResult.psm1
using module ..\BasePresenter.psm1
using module .\shared\SelectInstancePresenter.psm1
using module ..\..\Service\InstanceService.psm1
using module ..\..\Dto\InstanceDto.psm1

# The instances Docker Desktop does not carry yet: the rows read here, the
# candidates filtered here - a state that cannot be read is not an offer -
# the pick and the two questions read in the view, the Dto built here, one
# call to the service. The ActionResult is the only way out.
class RegisterDockerPresenter : BasePresenter {
    hidden [InstanceService]$Service

    [SelectInstancePresenter]$Picker

    RegisterDockerPresenter([InstanceService]$service, [string]$viewsRoot, [string]$viewType) : base($viewsRoot, $viewType, "Instance") {
        $this.Service = $service
        $this.Picker = [SelectInstancePresenter]::new($viewsRoot, $viewType)
    }

    [ActionResult] Run([string]$target) {
        try {
            $rows = @($this.Service.GetAll())
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("RegisterDocker : $($_.Exception.Message)")
        }

        $live = @($rows | Where-Object { -not $_.IsArchive })
        $candidates = @($live | Where-Object { "$($_.Docker)" -eq "no" })

        $view = $this.GetView("RegisterDocker")

        # A name given on the command line is checked against the live rows:
        # one of ours, and one Docker Desktop does not carry - each refusal
        # says which of the two failed.
        $name = ""
        if ($target) {
            $row = @($live | Where-Object { "$($_.Name)" -ceq "$target" })
            if ($row.Count -eq 0) {
                $this.ShowFailure("'$target' is not an instance of this machine.")
                return [ActionResult]::Nok("RegisterDocker : no instance")
            }
            if ("$($row[0].Docker)" -eq "yes") {
                $view.ShowAlreadyRegistered("$target")
                return [ActionResult]::Nok("RegisterDocker : $target")
            }
            if ("$($row[0].Docker)" -ne "no") {
                $view.ShowSettingsUnreadable()
                return [ActionResult]::Nok("RegisterDocker : $target")
            }
            $name = "$target"
        } else {
            if ($candidates.Count -eq 0) {
                # Every state unknown means Docker Desktop itself is the
                # trouble; an empty candidate list among readable states is
                # just "nothing to register".
                if ($live.Count -gt 0 -and @($live | Where-Object { "$($_.Docker)" -ne "unknown" }).Count -eq 0) {
                    $view.ShowSettingsUnreadable()
                } else {
                    $view.ShowNoCandidates()
                }
                return [ActionResult]::Nok("RegisterDocker : none to register")
            }
            $name = $this.Picker.Pick("", $candidates)
            if (-not $name) { return [ActionResult]::Ok("RegisterDocker : cancelled") }
        }

        if (-not $view.AskRegister($name)) {
            $view.ShowCancelled("modified")
            return [ActionResult]::Ok("RegisterDocker : cancelled")
        }
        $restart = $view.AskRestartDocker()

        $dto = [RegisterDockerDto]::new()
        $dto.InstanceName = $name
        $dto.Restart = $restart

        try {
            $response = $this.Service.RegisterDocker($dto)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("RegisterDocker : $name - $($_.Exception.Message)")
        }
        $view.Show($response)
        return [ActionResult]::Ok("RegisterDocker : $name")
    }
}
