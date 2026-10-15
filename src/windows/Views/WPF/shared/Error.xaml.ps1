# ==============================================================================
# THE ERROR BOX — THE WPF VIEW
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewWpf.psm1
using module ..\..\..\ViewModels\ErrorViewModel.psm1

# The error box: the entry's words, when and at which level it came, one OK.
# Nothing is answered - it is read and closed.
class WpfErrorView : BaseViewWpf {
    hidden [object]$Vm = $null

    [object] Ask([object]$entry) {
        $self = $this
        $this.Vm = [ErrorViewModel]::new($entry)

        $this.Title = "Error"
        $this.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
        $this.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $this.ResizeMode = [System.Windows.ResizeMode]::NoResize
        $this.Load((Join-Path $PSScriptRoot "Error.xaml"))
        $this.WearDefault()
        $this.Dress($null, 15)
        $this.DataContext = $this.Vm

        # Un seul bouton : Entrée ou Échap le pressent, clic idem.
        $this.Find("BtnErrorOk").Add_Click({ $self.Close() })

        $this.FitToContent($null)
        $null = $this.OpenAs($null)
        return $null
    }
}
