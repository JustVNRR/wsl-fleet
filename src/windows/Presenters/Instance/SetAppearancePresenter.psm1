using module ..\ActionResult.psm1
using module ..\BasePresenter.psm1
using module .\shared\SelectInstancePresenter.psm1
using module ..\..\Services\InstanceService.psm1
using module ..\..\Dtos\InstanceDto.psm1

class SetAppearancePresenter : BasePresenter {

    hidden [InstanceService]$Service
    [SelectInstancePresenter]$Picker

    SetAppearancePresenter([InstanceService]$service, [string]$viewsRoot, [string]$viewType) : base($viewsRoot, $viewType, "Instance") {
        $this.Service = $service
        $this.Picker = [SelectInstancePresenter]::new($viewsRoot, $viewType)
    }

    [ActionResult] Run([string]$target) {
        try {
            $rows = @($this.Service.GetAll())
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("SetAppearance : $($_.Exception.Message)")
        }

        $name = $this.Picker.Pick($target, $rows)
        if (-not $name) {
            if ($this.Picker.Miss -eq "none") { return [ActionResult]::Nok("SetAppearance : no instance") }
            return [ActionResult]::Ok("SetAppearance : cancelled")
        }

        $view = $this.GetView("SetAppearance")
        try {
            $appearance = $this.Service.GetAppearance($name)
            $fonts = @($this.Service.GetFonts())
            if ("$($appearance.Font)" -and $fonts -notcontains "$($appearance.Font)") {
                $fonts += "$($appearance.Font)"
            }
            $schemes = @($this.Service.GetColorSchemes())
            $pairs = @($this.Service.GetIconPairs())
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("SetAppearance : $name - $($_.Exception.Message)")
        }

        if (-not $appearance.HasFragment) {
            $view.ShowNoFragmentWarning()
        }

        $font = "$($appearance.Font)"
        $scheme = "$($appearance.ColourScheme)"

        $recipe = [WslIconDto]::new()
        if ($appearance.Icon) {
            $recipe.Text = "$($appearance.Icon.Text)"
            $recipe.Top = "$($appearance.Icon.Top)"
            $recipe.Bottom = "$($appearance.Icon.Bottom)"
            $recipe.TextColor = "$($appearance.Icon.TextColor)"
        }

        while ($true) {
            $chosen = $view.AskTheme($name)
            if (-not $chosen) { return [ActionResult]::Ok("SetAppearance : cancelled") }

            $dto = [SetAppearanceDto]::new()
            $dto.InstanceName = $name
            $changed = $false

            if ($chosen -eq "font") {
                $picked = $view.AskFont($name, $fonts, $font)
                if ($picked) { $dto.Font = $picked; $font = $picked; $changed = $true }
            } elseif ($chosen -eq "color") {
                $picked = $view.AskColour($name, $schemes, $scheme)
                if ($picked) { $dto.ColourScheme = $picked; $scheme = $picked; $changed = $true }
            } else {
                while ($true) {
                    $how = $view.AskIconType($name)
                    if (-not $how) { break }

                    if ($how -eq "auto") {
                        $recipe.Text = ""; $recipe.Top = ""; $recipe.Bottom = ""; $recipe.TextColor = ""
                        $dto.Icon = $this.CopyRecipe($recipe)
                        $dto.IconImage = ""
                        $changed = $true
                        break
                    } elseif ($how -eq "letters") {
                        $suggestion = "$($recipe.Text)"
                        $question = if ($suggestion) { "Letters, 1 to 3 [$suggestion]" } else { "Letters, 1 to 3" }
                        $settled = $false
                        while ($true) {
                            $answer = $view.AskLetters($question)
                            if ($null -eq $answer) { break }
                            if ([string]::IsNullOrWhiteSpace($answer)) {
                                if ($suggestion) { $recipe.Text = $suggestion.ToUpper(); $settled = $true }
                                break
                            }
                            if ($answer -match '^[A-Za-z0-9]{1,3}$') { $recipe.Text = $answer.ToUpper(); $settled = $true; break }
                            $view.ShowLettersHint()
                        }
                        if (-not $settled) { continue }
                        $dto.Icon = $this.CopyRecipe($recipe)
                        $dto.IconImage = ""
                        $changed = $true
                        break
                    } elseif ($how -eq "colours") {
                        $suggestion = "$($recipe.Text)"
                        $pair = $view.AskIconPair($name, $pairs, $suggestion, "$($recipe.Top)", "$($recipe.Bottom)")
                        if (-not $pair) { continue }
                        $recipe.Top = "$($pair.Top)"
                        $recipe.Bottom = "$($pair.Bottom)"
                        $recipe.TextColor = "$($pair.TextColor)"
                        $dto.Icon = $this.CopyRecipe($recipe)
                        $dto.IconImage = ""
                        $changed = $true
                        break
                    } else {
                        $settled = $false
                        while ($true) {
                            $answer = $view.AskImagePath()
                            if ($null -eq $answer) { break }
                            if (-not (Test-Path -LiteralPath $answer -PathType Leaf)) {
                                $view.ShowNoFile()
                                continue
                            }
                            if ((Split-Path -Leaf $answer) -notmatch '\.(png|jpg|jpeg|ico|bmp)$') {
                                $view.ShowBadExtension()
                                continue
                            }
                            $dto.IconImage = (Resolve-Path -LiteralPath $answer).Path
                            $settled = $true
                            break
                        }
                        if ($settled) { $changed = $true; break }
                    }
                }
            }

            if (-not $changed) { continue }

            try {
                $response = $this.Service.SetAppearance($dto)
            } catch {
                $this.ShowFailure($_.Exception.Message)
                return [ActionResult]::Nok("SetAppearance : $name - $($_.Exception.Message)")
            }
            $view.Show($response)
        }
        return [ActionResult]::Ok("SetAppearance : cancelled")
    }

    hidden [WslIconDto] CopyRecipe([WslIconDto]$recipe) {
        $dto = [WslIconDto]::new()
        $dto.Text = $recipe.Text
        $dto.Top = $recipe.Top
        $dto.Bottom = $recipe.Bottom
        $dto.TextColor = $recipe.TextColor
        return $dto
    }
}
