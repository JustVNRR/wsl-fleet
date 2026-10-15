# ==============================================================================
# DOCKER REGISTER — THE WPF VIEW
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewWpf.psm1
using module ..\..\..\ViewModels\DockerRegisterViewModel.psm1

# The Docker Desktop door: the sentence follows the row's state, the restart
# box defaults on, APPLY hands the name and the box back, Cancel hands
# nothing.
class WpfDockerRegisterView : BaseViewWpf {
    hidden [object]$Vm = $null

    [object] Ask([string]$name, [string]$state) {
        $self = $this
        $this.Vm = [DockerRegisterViewModel]::new($name, $state)

        $this.Title = "Docker Desktop"
        $this.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
        $this.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $this.ResizeMode = [System.Windows.ResizeMode]::NoResize
        $this.Load((Join-Path $PSScriptRoot "DockerRegister.xaml"))
        $this.WearDefault()
        $this.Dress($null, 15)
        $this.DataContext = $this.Vm

        # La porte de fermeture — METHODE 1 : le ViewModel dit « j'ai fini »,
        # la vue ferme.
        $this.Vm.DemandeFermeture = { param($result) $self.Result = $result; $self.Close() }

        # Les liens sont à sens unique : la case est relayée au ViewModel.
        $this.Find("ChkRestart").Add_Checked({ param($box, $e) $self.Vm.SetRestart([bool]$box.IsChecked) })
        $this.Find("ChkRestart").Add_Unchecked({ param($box, $e) $self.Vm.SetRestart([bool]$box.IsChecked) })
        $this.Find("BtnDockerCancel").Add_Click({ $self.Close() })

        $this.FitToContent($null)
        $null = $this.OpenAs($null)
        return $this.Result
    }
}
