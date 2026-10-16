using module ..\BaseViewWpf.psm1
using module ..\..\..\ViewModels\RootMoveViewModel.psm1

class WpfRootMoveView : BaseViewWpf {
    hidden [object]$Vm = $null

    [object] Ask([string]$current) {
        $self = $this
        $this.Vm = [RootMoveViewModel]::new($current)

        $this.Title = "Wsl Fleet"
        $this.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
        $this.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $this.ResizeMode = [System.Windows.ResizeMode]::NoResize
        $this.Load((Join-Path $PSScriptRoot "RootMove.xaml"))
        $this.WearDefault()
        $this.Dress($null, 15)
        $this.DataContext = $this.Vm

        $this.Vm.DemandeFermeture = { param($result) $self.Result = $result; $self.Close() }

        $this.Add_ContentRendered({ $null = $self.Find("TxtNewRoot").Focus(); $self.Find("TxtNewRoot").SelectAll() })

        $this.Find("TxtNewRoot").Add_TextChanged({ param($source, $e) $self.Vm.SetNewRoot("$($source.Text)") })
        $this.Find("BtnRootCancel").Add_Click({ $self.Close() })

        $this.FitToContent($null)
        $null = $this.OpenAs($null)
        return $this.Result
    }
}
