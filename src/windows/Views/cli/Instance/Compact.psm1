# ==============================================================================
# COMPACT — LA VUE DU CLI
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module qu'il a tiré lui-même.
using module ..\BaseViewCli.psm1
using module ..\..\..\Tools\Helpers.psm1

class CliCompactView : BaseViewCli {
    # La vue ne décide plus : la copie de sûreté est une question que le
    # presenter pose, l'écrasement une ligne qu'il a lue — ici, les affichages.

    [void] ShowBeforeQuestions() {
        Write-Host ""
    }

    # Pas de copie : la ligne le dit, et le compact continue.
    [void] ShowNoArchive() {
        Write-Host "  No archive - compacting on its own." -ForegroundColor $this.Colour("muted")
    }

    # L'écrasement, dit — le presenter l'a lu de l'index.
    [void] ShowReplacingArchive([string]$name) {
        Write-Host "  '$name' exists: replacing its archive." -ForegroundColor $this.Colour("warning")
    }

    # Les avis du geste qui part.
    [void] ShowCompacting([string]$name, [bool]$archiveFirst) {
        Write-Host ""
        Write-Host "  WARNING: THE INSTANCE WILL BE STOPPED." -ForegroundColor $this.Colour("warning")
        Write-Host "  Make sure nothing is running inside." -ForegroundColor $this.Colour("muted")
        Write-Host ""
        Write-Host "==> Reclaiming space in '$name'" -ForegroundColor $this.Colour("info")
        if ($archiveFirst) {
            Write-Host "==> Creating safety archive..." -ForegroundColor $this.Colour("info")
        }
        Write-Host "==> Compacting the virtual disk..." -ForegroundColor $this.Colour("info")
    }

    # Le rapport : la bannière, les tailles mesurées par le service — ce que
    # le disque pesait, ce qu'il pèse, ce qu'il a rendu —, la copie d'abord
    # quand elle a été prise, et le départ rendu quand l'instance était
    # debout.
    [void] Show([object]$response) {
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor $this.Colour("success")
        Write-Host "       '$($response.InstanceName)' compacted" -ForegroundColor $this.Colour("success")
        Write-Host "============================================================" -ForegroundColor $this.Colour("success")
        Write-Host ""
        Write-Host "  * Disk file        : " -NoNewline
        Write-Host "$(Format-Size $response.SizeBefore) -> $(Format-Size $response.SizeAfter)" -ForegroundColor $this.Colour("info")
        if ($response.Gained -gt 0) {
            Write-Host "  * Reclaimed        : " -NoNewline
            Write-Host "$(Format-Size $response.Gained)" -ForegroundColor $this.Colour("success")
        } else {
            Write-Host "  * Reclaimed        : " -NoNewline
            Write-Host "nothing - the disk held no space to give back" -ForegroundColor $this.Colour("muted")
        }
        if ($response.Archived) {
            Write-Host "  * Safety archive   : " -NoNewline; Write-Host "taken before the compact" -ForegroundColor $this.Colour("success")
        }
        if ($response.Restarted) {
            Write-Host "'$($response.InstanceName)' is running again." -ForegroundColor $this.Colour("success")
        }
        Write-Host ""
    }
}
