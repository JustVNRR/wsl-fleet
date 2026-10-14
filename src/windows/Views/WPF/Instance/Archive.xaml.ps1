# ==============================================================================
# ARCHIVE — LA VUE WPF
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewWpf.psm1
using module ..\..\..\Dto\InstanceDto.psm1

# La porte de l'archive, la même question qu'au cli : l'arrêt se dit toujours
# (la phrase couvre les deux cas — rien ne lit qui tourne), le nom de
# l'archive ne se demande pas (XX devient XX_archive : la règle du modèle),
# et la ligne de l'écrasement se lit de l'index reçu. Entrée est ARCHIVE,
# Échap est Cancel.
class WpfArchiveView : BaseViewWpf {
    [object] Ask([string]$name, [object[]]$rows) {
        $self = $this
        $this.Title = "Archive instance"
        $this.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
        $this.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $this.ResizeMode = [System.Windows.ResizeMode]::NoResize
        $this.Load((Join-Path $PSScriptRoot "Archive.xaml"))
        $this.WearDefault()
        $this.Dress($null, 15)

        $this.Find("TxtLead").Text = "Back up '$name' as '${name}_archive'."

        $existing = @($rows | Where-Object { $_.IsArchive -and "$($_.Name)" -eq "${name}_archive" })
        if ($existing.Count -gt 0) {
            $this.Find("TxtTaken").Visibility = [System.Windows.Visibility]::Visible
        }

        $this.Find("BtnArchiveCancel").Add_Click({ $self.Result = $null; $self.Close() })
        $this.Find("BtnArchiveGo").Add_Click({
            $dto = [ArchiveDto]::new()
            $dto.InstanceName = $name
            $dto.Format = "tar.gz"
            $dto.Permit = $true
            $self.Result = $dto
            $self.Close()
        })

        $this.FitToContent($null)
        $null = $this.OpenAs($null)
        return $this.Result
    }

    # Le rapport — la ligne d'état de la fenêtre principale le porte.
    [void] Show([string]$name, [object]$response) {
    }
}
