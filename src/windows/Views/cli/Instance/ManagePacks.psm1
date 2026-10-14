# ==============================================================================
# MANAGEPACKS — LA VUE DU CLI
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewCli.psm1
using module ..\..\..\Dto\InstanceDto.psm1

class CliManagePacksView : BaseViewCli {
    # La question du geste : la checklist — les offrables qui manquent
    # (décochés) et les portés qu'un utilisateur choisit (cochés), les deux
    # listes du service réunies en lignes par le contrôleur. Les requirements,
    # les invisibles et les refus de retrait se résolvent au service.
    [object] Ask([object]$packs, [string]$name) {
        $Installed = @($packs.Installed)

        $Rows = @()
        $CheckedIndexes = @()
        $taken = @{}
        foreach ($pack in @($packs.Candidate)) {
            $Rows += [PSCustomObject]@{ Name = $pack.Name; Description = $pack.Description }
            $taken[$pack.Name] = $true
        }
        foreach ($removable in @($packs.Removable)) {
            if ($taken.ContainsKey($removable)) { continue }
            $CheckedIndexes += $Rows.Count
            $Rows += [PSCustomObject]@{ Name = $removable; Description = "" }
        }

        if ($Rows.Count -eq 0) {
            Write-Host ""
            Write-Host "[OK] '$name' carries nothing to choose and this repository offers nothing to add." -ForegroundColor $this.Colour("success")
            return $null
        }

        $Chosen = $this.AskChecklist("Packs for '$name'", $Rows, {
            param($Row)
            "{0,-12} {1}" -f $Row.Name, $Row.Description
        }, $CheckedIndexes, "")

        if ($null -eq $Chosen) { $this.StopCancelled("modified") }
        $ticked = @($Chosen | ForEach-Object { $_.Name })

        # Ticked and not installed goes in; carried and unticked comes out.
        $ToAdd = @($ticked | Where-Object { $Installed -notcontains $_ })
        $ToRemove = @($packs.Removable | Where-Object { $ticked -notcontains $_ })

        if ($ToAdd.Count -eq 0 -and $ToRemove.Count -eq 0) {
            Write-Host ""
            Write-Host "[OK] Nothing to do: '$name' already has exactly that." -ForegroundColor $this.Colour("success")
            return $null
        }

        Write-Host ""
        if ($ToAdd.Count -gt 0) {
            Write-Host "==> Installing: $($ToAdd -join ', ')" -ForegroundColor $this.Colour("info")
        }
        if ($ToRemove.Count -gt 0) {
            Write-Host "==> Removing: $($ToRemove -join ', ')" -ForegroundColor $this.Colour("info")
        }

        $dto = [ManagePacksDto]::new()
        $dto.InstanceName = $name
        $dto.ToAdd = @($ToAdd)
        $dto.ToRemove = @($ToRemove)
        return $dto
    }

    # Le rapport : ce qui a bougé, lu des deux listages du service. La liste
    # entière des portés et le pas qui a échoué n'ont plus de source — la
    # réponse porte les entrés, les sortis et le nom du failli.
    [void] Show([string]$name, [object]$response) {
        # A failure names the pack; the packs already applied stay.
        if ($response.Outcome -eq "failed") {
            Write-Host ""
            Write-Host "[FAIL] '$($response.Failed -join ', ')' did not complete (exit code $($response.ExitCode))." -ForegroundColor $this.Colour("error")
            Write-Host "       The packs already applied stay - run this again to finish." -ForegroundColor $this.Colour("hint")
            Write-Host ""
            return
        }

        Write-Host ""
        if ($response.Installed.Count -gt 0) {
            Write-Host "==> '$name' now carries: $($response.Installed -join ', ')" -ForegroundColor $this.Colour("success")
            Write-Host "    Open a shell in it to use them:  .\wsl.ps1 shell" -ForegroundColor $this.Colour("muted")
        }
        if ($response.Removed.Count -gt 0) {
            Write-Host "==> Gone from '$name': $($response.Removed -join ', ')" -ForegroundColor $this.Colour("success")
        }
    }
}
