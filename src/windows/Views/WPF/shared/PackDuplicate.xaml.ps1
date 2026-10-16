# ==============================================================================
# LA COPIE D'UN PACK — LA VUE WPF
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewWpf.psm1
using module ..\..\..\ViewModels\PackDuplicateViewModel.psm1

# La petite fenêtre de duplication d'un pack : le DataContext est le
# PackDuplicateViewModel — le nom, la description et la ligne rouge s'y
# bindent. Ici, ce que WPF demande : le chargement, le focus d'ouverture, le
# relais des saisies, la porte de fermeture — et le nom rendu.
class WpfPackDuplicateView : BaseViewWpf {
    hidden [object]$Vm = $null

    [object] Ask([string]$source, [string]$description, [string[]]$taken) {
        $self = $this
        $this.Vm = [PackDuplicateViewModel]::new($source, $description, $taken)

        $this.Title = "Wsl Fleet"
        $this.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
        $this.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $this.ResizeMode = [System.Windows.ResizeMode]::NoResize
        $this.Load((Join-Path $PSScriptRoot "PackDuplicate.xaml"))
        $this.WearDefault()
        $this.Dress($null, 15)
        $this.DataContext = $this.Vm

        # La porte de fermeture — METHODE 1 : le ViewModel dit « j'ai fini »,
        # la vue ferme.
        $this.Vm.DemandeFermeture = { param($result) $self.Result = $result; $self.Close() }

        $this.Add_ContentRendered({ $null = $self.Find("TxtDupName").Focus(); $self.Find("TxtDupName").SelectAll() })

        # Les liens sont à sens unique : les saisies sont relayées au
        # ViewModel.
        $this.Find("TxtDupName").Add_TextChanged({ param($box, $e) $self.Vm.SetName("$($box.Text)") })
        $this.Find("TxtDupDescription").Add_TextChanged({ param($box, $e) $self.Vm.SetDescription("$($box.Text)") })
        $this.Find("BtnDupCancel").Add_Click({ $self.Close() })

        $this.FitToContent($null)
        $null = $this.OpenAs($null)
        return $this.Result
    }
}
