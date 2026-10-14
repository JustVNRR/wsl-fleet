# ==============================================================================
# LA QUESTION DE LA RACINE — LA VUE WPF
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewWpf.psm1
using module ..\..\..\ViewModels\RootMoveViewModel.psm1

# La question du déplacement de la racine : le DataContext est le
# RootMoveViewModel — l'avertissement, le dossier et la garde s'y bindent.
# Ici, ce que WPF demande : le chargement, le focus d'ouverture, le relais de
# la saisie, la porte de fermeture — et le dossier rendu.
class WpfRootMoveView : BaseViewWpf {
    hidden [object]$Vm = $null

    [object] Ask([string]$current) {
        $self = $this
        $this.Vm = [RootMoveViewModel]::new($current)

        $this.Title = "WSL Stack"
        $this.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
        $this.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $this.ResizeMode = [System.Windows.ResizeMode]::NoResize
        $this.Load((Join-Path $PSScriptRoot "RootMove.xaml"))
        $this.WearDefault()
        $this.Dress($null, 15)
        $this.DataContext = $this.Vm

        # La porte de fermeture — METHODE 1 : le ViewModel dit « j'ai fini »,
        # la vue ferme.
        $this.Vm.DemandeFermeture = { $self.Close() }

        $this.Add_ContentRendered({ $null = $self.Find("TxtNewRoot").Focus(); $self.Find("TxtNewRoot").SelectAll() })

        # Le lien est à sens unique : la saisie est relayée au ViewModel.
        $this.Find("TxtNewRoot").Add_TextChanged({ param($source, $e) $self.Vm.SetNewRoot("$($source.Text)") })
        $this.Find("BtnRootCancel").Add_Click({ $self.Close() })

        $this.FitToContent($null)
        $null = $this.OpenAs($null)
        return $this.Vm.Result
    }
}
