using module ..\ActionResult.psm1
using module ..\BasePresenter.psm1
using module ..\..\Services\InstanceService.psm1
using module ..\..\Dtos\InstanceDto.psm1

class BuildPresenter : BasePresenter {

    hidden [InstanceService]$Service

    BuildPresenter([InstanceService]$service, [string]$viewsRoot, [string]$viewType) : base($viewsRoot, $viewType, "Instance") {
        $this.Service = $service
    }

    [ActionResult] Run() {
        $view = $this.GetView("Build")
        try {
            $sources = $this.Service.GetBuildSources()
            $images = @($this.Service.GetAllSavedImages())
            $packs = @($this.Service.GetBuildPacks())
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Build : $($_.Exception.Message)")
        }

        $name = ""
        $road = $null
        $buildPath = ""
        $context = ""
        $family = ""
        $packNames = @()
        $onboarding = ""
        $user = ""
        $keep = $false
        $register = $false
        $done = $false

        $stack = [System.Collections.Generic.List[string]]::new()
        $stack.Add("name")
        while ($stack.Count -gt 0) {
            $step = $stack[$stack.Count - 1]
            switch ("$step") {
                "name" {
                    $ok = $false
                    while ($true) {
                        $answer = $view.AskInstanceName("Name of the instance (CTRL+C to abort)")
                        if ($null -eq $answer -or [string]::IsNullOrWhiteSpace($answer)) { break }
                        $answer = "$answer".Trim()
                        if ($answer -match '^[A-Za-z0-9][A-Za-z0-9_.-]*$') { $name = $answer; $ok = $true; break }
                        $view.ShowNameHint()
                    }
                    if ($ok) { $stack.Add("road") } else { $stack.Clear() }
                }
                "road" {
                    $picked = $view.AskRoad()
                    if (-not $picked) {
                        $stack.RemoveAt($stack.Count - 1)
                    } else {
                        $road = $picked
                        if ($road.Type -eq [WslBuildType]::Registry) {
                            $stack.Add("reference")
                        } else {
                            $rows = if ($road.Type -eq [WslBuildType]::Image) { @($images) }
                                    elseif ($road.Type -eq [WslBuildType]::Recipe) { @($sources.Recipes) }
                                    else { @($sources.Dockerfiles) }
                            if ($rows.Count -eq 0) {
                                if ($road.Type -eq [WslBuildType]::Image) {
                                    $view.ShowAbort(@("No Docker image under 'assets\dockerimages'.", "Upload one, or pick another road.", "Nothing was modified."))
                                    return [ActionResult]::Nok("Build : no Docker image")
                                }
                                if ($road.Type -eq [WslBuildType]::Recipe) {
                                    $view.ShowAbort(@("No recipe under 'assets\recipes'.", "Create one with the window's + button.", "Nothing was modified."))
                                    return [ActionResult]::Nok("Build : no recipe")
                                }
                                $view.ShowAbort(@("No Dockerfile under 'assets\dockerfiles'.", "Upload one, or delete that folder to get the repository's own back.", "Nothing was modified."))
                                return [ActionResult]::Nok("Build : no Dockerfile")
                            }
                            if ($rows.Count -eq 1 -and $road.Type -ne [WslBuildType]::Recipe) {
                                $picked = $rows[0]
                                $buildPath = "$($picked.Path)"
                                if ($road.Type -eq [WslBuildType]::Dockerfile) {
                                    $context = Split-Path -Parent $buildPath
                                    $family = "$($picked.Family)"
                                }
                                if ($packs.Count -gt 0) { $stack.Add("packs") } else { $stack.Add($this.NextAfterPacks(@($sources.Onboardings).Count, $road)) }
                            } else {
                                $stack.Add("source")
                            }
                        }
                    }
                }
                "reference" {
                    $ok = $false
                    while ($true) {
                        $reference = $view.AskRegistryReference("Docker image from a registry (e.g. alpine:latest)")
                        if ($null -eq $reference -or [string]::IsNullOrWhiteSpace($reference)) { break }
                        $verdict = $this.Service.IsRegistryImageValid($reference)
                        if ($verdict.Valid) { $buildPath = $reference; $ok = $true; break }
                        $view.ShowUnknownRegistry($reference, "$($verdict.Why)")
                    }
                    if (-not $ok) {
                        $stack.RemoveAt($stack.Count - 1)
                    } elseif ($packs.Count -gt 0) {
                        $stack.Add("packs")
                    } else {
                        $stack.Add($this.NextAfterPacks(@($sources.Onboardings).Count, $road))
                    }
                }
                "source" {
                    $rows = if ($road.Type -eq [WslBuildType]::Image) { @($images) }
                            elseif ($road.Type -eq [WslBuildType]::Recipe) { @($sources.Recipes) }
                            else { @($sources.Dockerfiles) }
                    $picked = $view.AskSource("$($road.Label)", $rows)
                    if (-not $picked) {
                        $stack.RemoveAt($stack.Count - 1)
                    } else {
                        if ($road.Type -eq [WslBuildType]::Recipe) {
                            $context = "$($picked.Path)"
                            $buildPath = Join-Path $context "Dockerfile"
                            $family = "$($picked.Family)"
                        } else {
                            $buildPath = "$($picked.Path)"
                            if ($road.Type -eq [WslBuildType]::Dockerfile) {
                                $context = Split-Path -Parent $buildPath
                                $family = "$($picked.Family)"
                            }
                        }
                        if ($packs.Count -gt 0) { $stack.Add("packs") } else { $stack.Add($this.NextAfterPacks(@($sources.Onboardings).Count, $road)) }
                    }
                }
                "packs" {
                    $offered = if ($family) { @($packs | Where-Object { $_.Family -eq $family }) } else { @($packs) }
                    $note = if ($family) { "" } else { "This recipe's system cannot be read - a pack made for another one will fail to install." }
                    $checked = @()
                    for ($index = 0; $index -lt $offered.Count; $index++) {
                        if ($family -and $offered[$index].Shell -and $offered[$index].Family -eq $family) { $checked += $index }
                    }
                    $chosen = $view.AskPacks($name, $offered, $checked, $note)
                    if ($null -eq $chosen) {
                        $stack.RemoveAt($stack.Count - 1)
                    } else {
                        $packNames = @($chosen | ForEach-Object { $_.Name })
                        if ($packNames.Count -eq 0) { $view.ShowNoPackChosen() }
                        $stack.Add($this.NextAfterPacks(@($sources.Onboardings).Count, $road))
                    }
                }
                "onboarding" {
                    $run = $view.AskRunOnboarding($road.Type -eq [WslBuildType]::Recipe)
                    if ($null -eq $run) {
                        $stack.RemoveAt($stack.Count - 1)
                    } elseif (-not $run) {
                        $onboarding = ""
                        $stack.Add($this.NextAfterOnboarding($road))
                    } else {
                        $picked = $view.AskOnboarding(@($sources.Onboardings))
                        if ($picked) {
                            $onboarding = "$($picked.Path)"
                            $stack.Add("user")
                        }
                    }
                }
                "user" {
                    $proposal = "$env:USERNAME".ToLower()
                    $proposal = $proposal.Normalize([Text.NormalizationForm]::FormD) -replace '\p{Mn}', ''
                    $proposal = $proposal -replace '[^a-z0-9_-]+', '-'
                    $proposal = $proposal.Trim('-', '_')
                    if (-not ($proposal -cmatch '^[a-z][a-z0-9_-]*$')) { $proposal = "" }

                    $prompt = "User name for '$name' (CTRL+C to abort)"
                    if ($proposal) { $prompt = "User name for '$name' [$proposal] (CTRL+C to abort)" }
                    $view.ShowBeforeAccount()
                    $ok = $false
                    while ($true) {
                        $answer = $view.AskUserName($prompt)
                        if ($null -eq $answer) { break }
                        if (-not $answer -and $proposal) { $answer = $proposal }
                        if ("$answer" -cmatch '^[a-z][a-z0-9_-]*$') { $user = $answer; $ok = $true; break }
                        $view.ShowUserHint()
                    }
                    if (-not $ok) {
                        $stack.RemoveAt($stack.Count - 1)
                    } else {
                        $stack.Add($this.NextAfterOnboarding($road))
                    }
                }
                "keep" {
                    $answer = $view.AskKeepImage()
                    if ($null -eq $answer) {
                        $stack.RemoveAt($stack.Count - 1)
                    } else {
                        $keep = [bool]$answer
                        $stack.Add("register")
                    }
                }
                "register" {
                    $answer = $view.AskRegisterDocker($name)
                    if ($null -eq $answer) {
                        $stack.RemoveAt($stack.Count - 1)
                    } else {
                        $register = [bool]$answer
                        $done = $true
                        $stack.Clear()
                    }
                }
            }
        }

        if (-not $done) {
            $view.ShowCancelled("modified")
            return [ActionResult]::Ok("Build : cancelled")
        }

        $dto = [BuildDto]::new()
        $dto.Name = $name
        $dto.User = $user
        $dto.BuildType = $road.Type
        $dto.BuildPath = $buildPath
        $dto.Context = $context
        $dto.Onboarding = $onboarding
        $dto.Packs = @($packNames)
        $dto.KeepImage = $keep
        $dto.RegisterDocker = $register

        if (-not ($this.Service.StartDocker())) {
            $view.ShowAbort(@("Docker is not responding.", "Start Docker Desktop, then try again."))
            return [ActionResult]::Nok("Build : Docker is not responding.")
        }
        try {
            $response = $this.Service.Build($dto)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Build : $($dto.Name) - $($_.Exception.Message)")
        }
        $view.Show($response)
        try { $null = $this.Service.Open($dto.Name) } catch { }
        return [ActionResult]::Ok("Build : $($dto.Name)")
    }

    hidden [string] NextAfterPacks([int]$boots, [object]$road) {
        if ($boots -eq 0) {
            $this.GetView("Build").ShowNoOnboarding()
            return $this.NextAfterOnboarding($road)
        }
        return "onboarding"
    }

    hidden [string] NextAfterOnboarding([object]$road) {
        if ($road.Type -in @([WslBuildType]::Dockerfile, [WslBuildType]::Recipe)) { return "keep" }
        return "register"
    }
}
