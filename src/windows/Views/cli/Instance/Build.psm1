using module ..\BaseViewCli.psm1
using module ..\..\..\Dtos\InstanceDto.psm1

class CliBuildView : BaseViewCli {

    [void] ShowNameHint() {
        Write-Host "  Letters, digits, '.', '_' and '-' only." -ForegroundColor $this.Colour("hint")
    }

    [object] AskInstanceName([string]$question) {
        return $this.AskLine($question)
    }

    [object] AskRoad() {
        $roads = @(
            [PSCustomObject]@{ Type = [WslBuildType]::Dockerfile; Label = "Dockerfile" },
            [PSCustomObject]@{ Type = [WslBuildType]::Image;      Label = "Docker image" },
            [PSCustomObject]@{ Type = [WslBuildType]::Registry;   Label = "Docker registry" },
            [PSCustomObject]@{ Type = [WslBuildType]::Recipe;     Label = "Recipe" }
        )
        $road = $this.AskList("Build from", $roads, { param($row) $row.Label }, "")
        if ($null -eq $road) { return "" }
        return $road
    }

    [object] AskRegistryReference([string]$question) {
        Write-Host -NoNewline "${question}: "
        $answer = $this.AskLine("")
        if ($null -eq $answer) { return $null }
        return "$answer".Trim()
    }

    [void] ShowUnknownRegistry([string]$reference, [string]$why) {
        Write-Host "  Unknown registry image '$reference' - $why" -ForegroundColor $this.Colour("warning")
    }

    [void] ShowAbort([string[]]$lines) {
        Write-Host ""
        $first = $true
        foreach ($line in @($lines)) {
            if ($first) {
                Write-Host "[ABORT] $line" -ForegroundColor $this.Colour("error")
                $first = $false
            } else {
                Write-Host "        $line" -ForegroundColor $this.Colour("hint")
            }
        }
    }

    [object] AskSource([string]$label, [object[]]$rows) {
        $picked = $this.AskList($label, @($rows), { param($row) $row.Name }, "")
        if ($null -eq $picked) { return "" }
        return $picked
    }

    [object[]] AskPacks([string]$name, [object[]]$offered, [int[]]$checked, [string]$note) {
        return $this.AskChecklist("Packs for '$name'", @($offered), {
            param($pack)
            "{0,-12} [{1}] {2}" -f $pack.Name, $pack.Family, $pack.Description
        }, @($checked), $note)
    }

    [void] ShowNoPackChosen() {
        Write-Host ""
        Write-Host "[OK] No pack selected." -ForegroundColor $this.Colour("success")
    }

    [void] ShowNoOnboarding() {
        Write-Host ""
        Write-Host "  No onboarding shell under 'assets\onboardings' - the instance will be built without one." -ForegroundColor $this.Colour("muted")
    }

    [object] AskRunOnboarding([bool]$defaultNo) {
        Write-Host ""
        return $this.Confirm("Run the onboarding shell?", $defaultNo)
    }

    [object] AskOnboarding([object[]]$boots) {
        $picked = $this.AskList("Onboarding shell", @($boots), { param($row) $row.Name }, "")
        if ($null -eq $picked) { return "" }
        return $picked
    }

    [void] ShowBeforeAccount() {
        Write-Host ""
    }

    [object] AskUserName([string]$prompt) {
        Write-Host -NoNewline "${prompt}: " -ForegroundColor $this.Colour("warning")
        $answer = $this.AskLine("")
        if ($null -eq $answer) { return $null }
        return "$answer".Trim()
    }

    [void] ShowUserHint() {
        Write-Host "  Lowercase letters, digits, '_' and '-' only, starting with a letter." -ForegroundColor $this.Colour("hint")
    }

    [object] AskKeepImage() {
        Write-Host ""
        return $this.Confirm("Keep Docker image?", $false)
    }

    [object] AskRegisterDocker([string]$name) {
        Write-Host ""
        return $this.Confirm("Add '$name' to Docker Desktop? (it will be restarted)", $false)
    }

    [void] Show([object]$response) {
        foreach ($message in @($response.Messages)) {
            Write-Host ""
            Write-Host "  $message" -ForegroundColor $this.Colour("muted")
        }
        Write-Host ""
        Write-Host "==> Built '$($response.InstanceName)' ($($response.Status))." -ForegroundColor $this.Colour("success")
        Write-Host ""
    }
}
