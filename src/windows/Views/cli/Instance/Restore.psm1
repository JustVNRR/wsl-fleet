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

    # La vue ne décide plus : le presenter a constaté le vide et l'abandon,
    # et c'est lui qui lit ce que le nom tapé veut dire — ici, le menu, la
    # ligne du nom et les questions.

    # L'archive se choisit : l'index reçu, ses lignes d'archives. Rien quand
    # on sort — le presenter le lit comme un abandon.
    [object] AskArchive([object[]]$archives) {
        $Chosen = $this.AskList("Archives (most recent first):", @($archives), {
            param($Entry)
            "{0}  -  {1}" -f $Entry.Name, (Format-Size $Entry.Size)
        }, "")
        if (-not $Chosen) { return "" }
        return "$($Chosen.Name)"
    }

    [void] ShowRestoring([string]$archiveName) {
        Write-Host ""
        Write-Host "Restoring $archiveName as a new instance." -ForegroundColor $this.Colour("info")
    }

    # Le nom de l'instance rebâtie, lu — Read-Host est demandé nu : ce qu'il
    # écrit lui-même n'atteint jamais un pipe. Un vide annule, c'est le
    # presenter qui le dit.
    [string] AskNewName() {
        return [string](Read-Host "Name of the new instance (Enter to cancel)").Trim()
    }

    # Le rapport : la bannière, l'archive d'où elle vient (-Target), et les
    # deux phrases d'après-restauration. Ce que la pose a fait du look et de
    # Docker Desktop n'a plus de source — la réponse ne porte que le nom
    # rebâti.
    [void] Show([object]$response) {
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor $this.Colour("success")
        Write-Host "       '$($response.InstanceName)' restored from an archive" -ForegroundColor $this.Colour("success")
        Write-Host "============================================================" -ForegroundColor $this.Colour("success")
        Write-Host ""
        Write-Host "  * From             : " -NoNewline; Write-Host "$($response.ArchiveName)" -ForegroundColor $this.Colour("info")
        Write-Host ""
        Write-Host "  The archive is kept." -ForegroundColor $this.Colour("hint")
        Write-Host "  Windows Terminal: restart it to see the icon, the font and the colour" -ForegroundColor $this.Colour("muted")
        Write-Host "  scheme that came back with the archive." -ForegroundColor $this.Colour("muted")
        Write-Host ""
    }
}
