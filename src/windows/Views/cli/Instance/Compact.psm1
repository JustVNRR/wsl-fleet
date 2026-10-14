# ==============================================================================
# COMPACT — LA VUE DU CLI
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewCli.psm1
using module ..\..\..\Dto\InstanceDto.psm1

class CliCompactView : BaseViewCli {
    # Les questions du geste : le nom est déjà choisi — la copie de sûreté
    # d'abord (oui par défaut, compacter réécrit les métadonnées du disque),
    # la ligne de l'écrasement lue de l'index reçu, puis les avis du geste qui
    # part.
    [object] Ask([string]$name, [object[]]$rows) {
        Write-Host ""
        $archiveFirst = $this.Confirm("Archive it first?", $false)
        if (-not $archiveFirst) {
            Write-Host "  No archive - compacting on its own." -ForegroundColor $this.Colour("muted")
        } else {
            $existing = @($rows | Where-Object { $_.IsArchive -and $_.Name -eq "$($name)_archive" })
            if ($existing.Count -gt 0) {
                Write-Host "  '$name' exists: replacing its archive." -ForegroundColor $this.Colour("warning")
            }
        }

        Write-Host ""
        Write-Host "  WARNING: THE INSTANCE WILL BE STOPPED." -ForegroundColor $this.Colour("warning")
        Write-Host "  Make sure nothing is running inside." -ForegroundColor $this.Colour("muted")
        Write-Host ""
        Write-Host "==> Reclaiming space in '$name'" -ForegroundColor $this.Colour("info")
        if ($archiveFirst) {
            Write-Host "==> Creating safety archive..." -ForegroundColor $this.Colour("info")
        }
        Write-Host "==> Compacting the virtual disk..." -ForegroundColor $this.Colour("info")

        $dto = [CompactDto]::new()
        $dto.InstanceName = $name
        $dto.ArchiveFirst = [bool]$archiveFirst
        return $dto
    }

    # Le rapport : la bannière, et la copie d'abord quand elle a été prise.
    # Les tailles d'avant et d'après n'ont plus de source — la réponse ne
    # porte que le nom et le oui de l'archivage.
    [void] Show([string]$name, [object]$response) {
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor $this.Colour("success")
        Write-Host "       '$name' compacted" -ForegroundColor $this.Colour("success")
        Write-Host "============================================================" -ForegroundColor $this.Colour("success")
        Write-Host ""
        if ($response.Archived) {
            Write-Host "  * Safety archive   : " -NoNewline; Write-Host "taken before the compact" -ForegroundColor $this.Colour("success")
        }
        Write-Host ""
    }
}
