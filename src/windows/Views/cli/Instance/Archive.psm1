# ==============================================================================
# ARCHIVE — LA VUE DU CLI
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewCli.psm1
using module ..\..\..\Dto\InstanceDto.psm1

class CliArchiveView : BaseViewCli {
    # Les questions du geste : le nom est déjà choisi — l'avis du disque
    # immobile, sans condition parce que rien ne lit qui tourne (la phrase
    # couvre les deux cas), et la ligne de l'écrasement, lue de l'index reçu.
    # Le nom de l'archive ne se demande pas : XX devient XX_archive. Le format
    # reste celui du dépôt, tar.gz.
    [object] Ask([string]$name, [object[]]$rows) {
        Write-Host ""
        Write-Host "  If '$name' is running, this will stop it: an archive reads a still disk." -ForegroundColor $this.Colour("warning")
        Write-Host "  Save what you have open in there - stopping it loses anything unsaved." -ForegroundColor $this.Colour("warning")
        if (-not $this.Confirm("Continue?", $false)) { $this.StopCancelled("modified") }

        $existing = @($rows | Where-Object { $_.IsArchive -and $_.Name -eq "$($name)_archive" })
        if ($existing.Count -gt 0) {
            Write-Host "  '$($name)_archive' exists: replacing it." -ForegroundColor $this.Colour("warning")
        }

        Write-Host ""
        Write-Host "==> Backing up '$name'" -ForegroundColor $this.Colour("info")

        $dto = [ArchiveDto]::new()
        $dto.InstanceName = $name
        $dto.Format = "tar.gz"
        $dto.Permit = $true
        return $dto
    }

    # Le rapport : la bannière, le look gardé à côté du tar, ce que Docker
    # Desktop savait, les chemins, et l'état rendu à l'instance.
    [void] Show([string]$name, [object]$response) {
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor $this.Colour("success")
        Write-Host "       Backup of '$name' written" -ForegroundColor $this.Colour("success")
        Write-Host "============================================================" -ForegroundColor $this.Colour("success")
        Write-Host ""
        Write-Host "  * Look             : font '$($response.LookFont)', colours '$($response.LookColourScheme)'" -ForegroundColor $this.Colour("muted")
        Write-Host "  * Docker Desktop   : $(if ($response.Docker -eq "yes") { "knows this instance" } elseif ($response.Docker -eq "no") { "does not know it" } else { "not installed, or unreadable" })" -ForegroundColor $this.Colour("muted")
        Write-Host "  * Archive          : " -NoNewline; Write-Host "$($response.ArchiveDir)" -ForegroundColor $this.Colour("info")
        Write-Host "  * Tar              : " -NoNewline; Write-Host "$(Split-Path -Leaf "$($response.Tar)")" -ForegroundColor $this.Colour("info")
        Write-Host ""
        Write-Host "------------------------------------------------------------" -ForegroundColor $this.Colour("muted")
        Write-Host "To restore it as a new instance:" -ForegroundColor $this.Colour("hint")
        Write-Host "  .\wsl.ps1 restore        (it lists the archives, this one included)" -ForegroundColor $this.Colour("hint")
        Write-Host "------------------------------------------------------------" -ForegroundColor $this.Colour("muted")
        Write-Host ""
        if ($response.Stopped) {
            Write-Host "'$name' is running again." -ForegroundColor $this.Colour("success")
        } else {
            Write-Host "'$name' is left stopped." -ForegroundColor $this.Colour("muted")
        }
        Write-Host ""
    }
}
