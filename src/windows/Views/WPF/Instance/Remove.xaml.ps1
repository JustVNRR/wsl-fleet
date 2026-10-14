# ==============================================================================
# LA DESTRUCTION — LA VUE WPF
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewWpf.psm1
using module ..\..\..\ViewModels\RemoveViewModel.psm1

class WpfRemoveView : BaseViewWpf {
    hidden [object]$Vm = $null

    [object] Ask([string]$name) {
        $self = $this
        $this.Vm = [RemoveViewModel]::new($name)
        $this.Title = "Remove instance"
        $this.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
        $this.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $this.ResizeMode = [System.Windows.ResizeMode]::NoResize
        $this.Load((Join-Path $PSScriptRoot "Remove.xaml"))
        $this.WearDefault()
        $this.Dress($null, 15)
        $this.DataContext = $this.Vm

        # La porte de fermeture — METHODE 1 : le ViewModel dit « j'ai fini »,
        # la vue ferme.
        $this.Vm.DemandeFermeture = { param($result) $self.Result = $result; $self.Close() }
        $this.Add_ContentRendered({ $null = $this.Find("ChkArchive").Focus() })

        # Les liens sont à sens unique : saisie et bascule relayées au
        # ViewModel, qui garde la porte du nom exact.
        $this.Find("TxtName").Add_TextChanged({ param($source, $e) $self.Vm.SetTyped("$($source.Text)") })
        $this.Find("ChkArchive").Add_Checked({ param($source, $e) $self.Vm.SetArchiveFirst([bool]$source.IsChecked) })
        $this.Find("ChkArchive").Add_Unchecked({ param($source, $e) $self.Vm.SetArchiveFirst([bool]$source.IsChecked) })

        $this.Find("BtnGateCancel").Add_Click({ $self.Close() })

        $this.FitToContent($null)
        $null = $this.OpenAs($null)
        return $this.Result
    }
}
