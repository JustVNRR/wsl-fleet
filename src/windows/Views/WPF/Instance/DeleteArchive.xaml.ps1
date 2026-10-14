# ==============================================================================
# DELETEARCHIVE — LA VUE WPF
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewWpf.psm1

# La porte de la suppression d'archive, la même fenêtre qu'aujourd'hui : la
# phrase avec le nom, et le nom exact retapé — le bouton ne s'éveille que sur
# lui, casse comprise. Entrée est DELETE, Échap est Cancel. Ask rend le nom
# confirmé, ou vide : le contrôleur en fait « cancelled ».
class WpfDeleteArchiveView : BaseViewWpf {
    [object] Ask([string]$archiveName) {
        $self = $this
        $this.Title = "Delete archive"
        $this.Width = 540
        $this.SizeToContent = [System.Windows.SizeToContent]::Height
        $this.MaxHeight = 760
        $this.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $this.ResizeMode = [System.Windows.ResizeMode]::NoResize
        $this.Load((Join-Path $PSScriptRoot "DeleteArchive.xaml"))
        $this.WearDefault()
        $this.Dress($null, 15)

        $this.Find("TxtLead").Text = "The archive '$archiveName' will be deleted and will not be restorable again."

        $txtName = $this.Find("TxtName")
        $btnDelete = $this.Find("BtnArchiveDelete")
        $this.Add_ContentRendered({ $null = $txtName.Focus() })

        $txtName.Add_TextChanged({
            # -ceq : le nom exact, casse comprise.
            $btnDelete.IsEnabled = ($txtName.Text -ceq $archiveName)
        })
        $this.Find("BtnArchiveCancel").Add_Click({ $self.Result = ""; $self.Close() })
        $btnDelete.Add_Click({ $self.Result = $archiveName; $self.Close() })

        $this.FitToContent($null)
        $null = $this.OpenAs($null)
        return $this.Result
    }

    # Le rapport — la ligne d'état de la fenêtre principale le porte.
    [void] Show([string]$name, [object]$response) {
    }
}
