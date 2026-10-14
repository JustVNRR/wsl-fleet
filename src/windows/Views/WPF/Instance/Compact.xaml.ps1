# ==============================================================================
# COMPACT — LA VUE WPF
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewWpf.psm1
using module ..\..\..\Dto\InstanceDto.psm1

# La porte de la compacité, la même fenêtre qu'aujourd'hui : la phrase avec le
# nom, l'avertissement d'arrêt, et la même case « archiver d'abord » que la
# corbeille. Entrée est COMPACT, Échap est Cancel. Ask rend le CompactDto ;
# le rapport reviendra avec la fenêtre principale.
class WpfCompactView : BaseViewWpf {
    [object] Ask([string]$name, [object[]]$rows) {
        $self = $this
        $this.Title = "Compact instance"
        $this.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
        $this.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $this.ResizeMode = [System.Windows.ResizeMode]::NoResize
        $this.Load((Join-Path $PSScriptRoot "Compact.xaml"))
        $this.WearDefault()
        $this.Dress($null, 15)

        $this.Find("TxtLead").Text = "Compacting '$name'."

        $chkArchive = $this.Find("ChkArchive")
        $this.Add_ContentRendered({ $null = $chkArchive.Focus() })

        $this.Find("BtnGateCancel").Add_Click({ $self.Result = $null; $self.Close() })
        $this.Find("BtnGateCompact").Add_Click({
            $dto = [CompactDto]::new()
            $dto.InstanceName = $name
            $dto.ArchiveFirst = [bool]$chkArchive.IsChecked
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
