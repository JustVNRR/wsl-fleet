# ==============================================================================
# LA LISTE — LA VUE DU CLI
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewCli.psm1
using module ..\..\..\Tools\Helpers.psm1

# Le tableau : les instances (qui tourne, la taille), les archives, et les
# dossiers laissés derrière — le seul endroit où ils se montrent. Rien à
# demander : le contrôleur a lu, la vue montre — et rien du tout s'abandonne
# ici, comme aujourd'hui.
class CliListView : BaseViewCli {
    [void] Show([object]$response) {
        $instances = @($response.Rows | Where-Object { -not $_.IsArchive })
        $archives = @($response.Rows | Where-Object { $_.IsArchive })
        $orphans = @($response.Orphans)
        $running = @($response.Running)

        if (($instances.Count + $archives.Count + $orphans.Count) -eq 0) {
            Write-Host ""
            Write-Host "[ABORT] No instance of this template is registered on this machine." -ForegroundColor $this.Colour("error")
            Write-Host "        Build one with  .\wsl-fleet.ps1 build" -ForegroundColor $this.Colour("hint")
            Write-Host ""
            return
        }

        if ($instances.Count -gt 0) {
            Write-Host ""
            Write-Host "Instances of this template:" -ForegroundColor $this.Colour("info")
            for ($Index = 0; $Index -lt $instances.Count; $Index++) {
                $entry = $instances[$Index]
                $state = if ($running -contains "$($entry.Name)") { "running" } else { "stopped" }
                Write-Host ("  {0,2}.  {1,-30} {2,-8} {3,10}  {4}" -f ($Index + 1), "$($entry.Name)", $state, (Format-Size ([double]$entry.Size)), "$($entry.Path)")
            }
        }

        if ($archives.Count -gt 0) {
            Write-Host ""
            Write-Host "Archives (most recent first):" -ForegroundColor $this.Colour("info")
            foreach ($entry in $archives) {
                Write-Host ("      {0,-30} {1,10}  {2}  {3}" -f "$($entry.Name)", (Format-Size ([double]$entry.Size)), "$($entry.Archived)", "$($entry.Path)")
            }
        }

        if ($orphans.Count -gt 0) {
            Write-Host ""
            Write-Host "Folders left behind by an instance that is gone:" -ForegroundColor $this.Colour("hint")
            foreach ($row in $orphans) {
                Write-Host ("      {0,-30} {1,10}  {2}" -f "$($row.Name)", (Format-Size ([double]$row.Size)), "$($row.Path)") -ForegroundColor $this.Colour("hint")
            }
            Write-Host "      No instance claims them, and no command removes them: delete them by hand." -ForegroundColor $this.Colour("muted")
        }
        Write-Host ""
    }
}
