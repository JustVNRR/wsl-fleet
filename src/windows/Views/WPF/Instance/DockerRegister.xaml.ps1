using module ..\BaseViewWpf.psm1
using module ..\..\..\ViewModels\DockerRegisterViewModel.psm1

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

        $this.Vm.DemandeFermeture = { param($result) $self.Result = $result; $self.Close() }

        $this.Find("ChkRestart").Add_Checked({ param($box, $e) $self.Vm.SetRestart([bool]$box.IsChecked) })
        $this.Find("ChkRestart").Add_Unchecked({ param($box, $e) $self.Vm.SetRestart([bool]$box.IsChecked) })
        $this.Find("BtnDockerCancel").Add_Click({ $self.Close() })

        $this.FitToContent($null)
        $null = $this.OpenAs($null)
        return $this.Result
    }
}
