using module ..\BaseViewWpf.psm1
using module ..\..\..\ViewModels\DuplicateViewModel.psm1

class WpfDuplicateView : BaseViewWpf {
    hidden [object]$Vm = $null

    [object] Ask([string]$source) {
        $self = $this
        $this.Vm = [DuplicateViewModel]::new($source)
        $this.Title = "Duplicate"
        $this.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
        $this.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $this.ResizeMode = [System.Windows.ResizeMode]::NoResize
        $this.Load((Join-Path $PSScriptRoot "Duplicate.xaml"))
        $this.WearDefault()
        $this.Dress($null, 15)
        $this.DataContext = $this.Vm

        $this.Vm.DemandeFermeture = { param($result) $self.Result = $result; $self.Close() }
        $this.Add_ContentRendered({ $null = $this.Find("TxtName").Focus(); $this.Find("TxtName").SelectAll() })

        $this.Find("TxtName").Add_TextChanged({ param($source, $e) $self.Vm.SetName("$($source.Text)") })

        $this.Find("BtnDupCancel").Add_Click({ $self.Close() })

        $this.FitToContent($null)
        $null = $this.OpenAs($null)
        return $this.Result
    }
}
