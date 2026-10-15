# ==============================================================================
# ARCHIVE — LA VUE DU CLI
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewCli.psm1
using module ..\..\..\Dto\InstanceDto.psm1

class CliArchiveView : BaseViewCli {
    # La vue ne décide plus : le presenter a ordonné chaque ligne, et la
    # question qu'il pose est lue par lui. Ici, les phrases.

    # L'avis du disque immobile — sans condition parce que rien ne lit qui
    # tourne (la phrase couvre les deux cas) ; la question « Continue ? » se
    # pose à la vue, mais c'est le presenter qui la pose.
    [void] ShowStopWarning([string]$name) {
        Write-Host ""
        Write-Host "  If '$name' is running, this will stop it: an archive reads a still disk." -ForegroundColor $this.Colour("warning")
        Write-Host "  Save what you have open in there - stopping it loses anything unsaved." -ForegroundColor $this.Colour("warning")
    }

    # L'écrasement, dit — le presenter l'a lu de l'index.
    [void] ShowReplacing([string]$archiveName) {
        Write-Host "  '$archiveName' exists: replacing it." -ForegroundColor $this.Colour("warning")
    }

    [void] ShowBackingUp([string]$name) {
        Write-Host ""
        Write-Host "==> Backing up '$name'" -ForegroundColor $this.Colour("info")
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
