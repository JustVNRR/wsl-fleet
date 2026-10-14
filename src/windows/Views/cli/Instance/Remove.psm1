# ==============================================================================
# REMOVE — LA VUE DU CLI
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewCli.psm1
using module ..\..\..\Dto\InstanceDto.psm1

class CliRemoveView : BaseViewCli {
    # Les questions du geste : le nom est déjà choisi — la porte qui demande le
    # nom retapé (la destruction), le dernier moment pour une copie, et la
    # ligne de l'écrasement, lue de l'index reçu.
    [object] Ask([string]$name, [object[]]$rows) {
        if (-not $this.ConfirmDestruction($name, "The WSL distribution '$name' and ALL its data will be deleted:")) {
            Write-Host "[ABORT] Operation cancelled. No data was modified." -ForegroundColor $this.Colour("warning")
            exit 0
        }

        Write-Host ""
        $archiveFirst = $this.Confirm("Archive it before deleting?", $true)
        if ($archiveFirst) {
            # Le même nom est remplacé — pas en silence : dit, l'archive qui
            # porte déjà ce nom se lit de l'index reçu.
            $existing = @($rows | Where-Object { $_.IsArchive -and $_.Name -eq "$($name)_archive" })
            if ($existing.Count -gt 0) {
                Write-Host "  '$name' exists: replacing its archive." -ForegroundColor $this.Colour("warning")
            }
        }

        Write-Host "==> Stopping the distro processes..." -ForegroundColor $this.Colour("info")
        Write-Host "==> Unregistering the distro..." -ForegroundColor $this.Colour("info")

        $dto = [RemoveDto]::new()
        $dto.InstanceName = $name
        $dto.ArchiveFirst = [bool]$archiveFirst
        return $dto
    }

    # Le rapport : la bannière, et la phrase de Windows Terminal. Les détails
    # de l'ancien écran — ce que le dossier est devenu, les comptes des
    # fantômes et des fragments, la copie — n'ont plus de source : le service
    # ne rend rien, et l'échec passe par la vue d'erreur.
    [void] Show([string]$name, [object]$response) {
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor $this.Colour("success")
        Write-Host "                WSL Stack Instance Removed!                 " -ForegroundColor $this.Colour("success")
        Write-Host "============================================================" -ForegroundColor $this.Colour("success")
        Write-Host ""
        Write-Host ""
        Write-Host " Restart Windows Terminal to refresh the profile list."
        Write-Host ""
    }
}
