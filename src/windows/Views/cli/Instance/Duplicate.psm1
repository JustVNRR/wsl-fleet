# ==============================================================================
# DUPLICATE — LA VUE DU CLI
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewCli.psm1
using module ..\..\..\Dto\InstanceDto.psm1

class CliDuplicateView : BaseViewCli {
    # Les questions du geste : le nom de la copie — tapé, il n'y a rien à
    # piocher — puis l'avis du disque immobile, qui couvre les deux cas sans
    # lire qui tourne. Docker Desktop ne se demande plus : la copie y entre
    # comme l'originale.
    [object] Ask([string]$source) {
        $copy = $this.AskName("Name of the copy", "created")

        Write-Host ""
        Write-Host "  If '$source' is running, this will stop it: the copy reads a still disk." -ForegroundColor $this.Colour("warning")
        Write-Host "  Save what you have open in there - stopping it loses anything unsaved." -ForegroundColor $this.Colour("warning")
        if (-not $this.Confirm("Continue?", $false)) { $this.StopCancelled("created") }

        Write-Host ""
        Write-Host "==> Duplicating '$source' into '$copy'" -ForegroundColor $this.Colour("info")
        Write-Host "==> 1. Reading the source (the source itself is not modified)..." -ForegroundColor $this.Colour("info")
        Write-Host "==> 2. Registering '$copy' from it..." -ForegroundColor $this.Colour("info")

        $dto = [DuplicateDto]::new()
        $dto.SourceName = $source
        $dto.CopyName = $copy
        return $dto
    }

    # Le rapport : la bannière — la copie (-Response) et l'originale (-Target)
    # — et les deux phrases de Terminal. La place, le look reposé, la réponse
    # de Docker Desktop et l'état rendu n'ont plus de source.
    [void] Show([string]$source, [object]$response) {
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor $this.Colour("success")
        Write-Host "       '$($response)' is a copy of '$source'" -ForegroundColor $this.Colour("success")
        Write-Host "============================================================" -ForegroundColor $this.Colour("success")
        Write-Host ""
        Write-Host "  Windows Terminal: the copy gets a profile of its own, with the icon," -ForegroundColor $this.Colour("muted")
        Write-Host "  the font and the colours of the source. Restart Terminal to see it." -ForegroundColor $this.Colour("muted")
        Write-Host ""
    }
}
