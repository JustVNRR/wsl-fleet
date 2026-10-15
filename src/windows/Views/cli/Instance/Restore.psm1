# ==============================================================================
# RESTORE — LA VUE DU CLI
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewCli.psm1
using module ..\..\..\Dto\InstanceDto.psm1
using module ..\..\..\Tools\Helpers.psm1

class CliRestoreView : BaseViewCli {
    # Rien à restaurer : le refus, peint ici une fois - le contrôleur l'a
    # constaté avant d'ouvrir la question, et sort en faute.
    [void] ShowNoArchives() {
        Write-Host ""
        Write-Host "[ABORT] There are no archives." -ForegroundColor $this.Colour("error")
        Write-Host "        Nothing to restore:" -ForegroundColor $this.Colour("hint")
        Write-Host "            - Create one with  .\wsl.ps1 archive" -ForegroundColor $this.Colour("hint")
    }

    # Les questions du geste : l'archive (l'index reçu, ses lignes d'archives
    # d'abord — une ligne déjà désignée se reprend telle quelle), puis le nom
    # de l'instance rebâtie. Rien ne se pré-vérifie — un nom pris, un dossier
    # en travers : c'est le service qui refuse, et la vue d'erreur qui le dit.
    # Docker Desktop ne se demande plus : l'instance y entre comme l'archive
    # le dit.
    [object] Ask([object[]]$rows, [string]$target) {
        $archiveName = $target
        if (-not $archiveName) {
            $Archives = @($rows | Where-Object { $_.IsArchive })
            $Chosen = $this.AskList("Archives (most recent first):", $Archives, {
                param($Entry)
                "{0}  -  {1}" -f $Entry.Name, (Format-Size $Entry.Size)
            }, "")
            if (-not $Chosen) { $this.StopCancelled("created") }
            $archiveName = $Chosen.Name
        }

        Write-Host ""
        Write-Host "Restoring $archiveName as a new instance." -ForegroundColor $this.Colour("info")
        $Name = [string](Read-Host "Name of the new instance (Enter to cancel)")
        if ([string]::IsNullOrWhiteSpace($Name)) { $this.StopCancelled("created") }
        $Name = $Name.Trim()

        $dto = [RestoreDto]::new()
        $dto.ArchiveName = $archiveName
        $dto.InstanceName = $Name
        return $dto
    }

    # Le rapport : la bannière, l'archive d'où elle vient (-Target), et les
    # deux phrases d'après-restauration. Ce que la pose a fait du look et de
    # Docker Desktop n'a plus de source — la réponse ne porte que le nom
    # rebâti.
    [void] Show([string]$archiveName, [object]$response) {
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor $this.Colour("success")
        Write-Host "       '$($response)' restored from an archive" -ForegroundColor $this.Colour("success")
        Write-Host "============================================================" -ForegroundColor $this.Colour("success")
        Write-Host ""
        Write-Host "  * From             : " -NoNewline; Write-Host "$archiveName" -ForegroundColor $this.Colour("info")
        Write-Host ""
        Write-Host "  The archive is kept." -ForegroundColor $this.Colour("hint")
        Write-Host "  Windows Terminal: restart it to see the icon, the font and the colour" -ForegroundColor $this.Colour("muted")
        Write-Host "  scheme that came back with the archive." -ForegroundColor $this.Colour("muted")
        Write-Host ""
    }
}
