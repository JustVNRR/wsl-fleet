using module ..\BaseViewWpf.psm1
using module ..\..\..\ViewModels\RestoreViewModel.psm1

class WpfRestoreView : BaseViewWpf {

    hidden [object]$Vm = $null

    [object] Ask([string]$archiveName) {
        $self = $this
        $this.Vm = [RestoreViewModel]::new($archiveName)
        $this.Title = "Restore archive"
        $this.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
        $this.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $this.ResizeMode = [System.Windows.ResizeMode]::NoResize
        $this.Load((Join-Path $PSScriptRoot "Restore.xaml"))
        $this.WearDefault()
        $this.Dress($null, 15)
        $this.DataContext = $this.Vm

        $this.Vm.DemandeFermeture = { param($result) $self.Result = $result; $self.Close() }
        $this.Add_ContentRendered({ $null = $this.Find("TxtName").Focus(); $this.Find("TxtName").SelectAll() })

        $this.Find("TxtName").Add_TextChanged({ param($source, $e) $self.Vm.SetName("$($source.Text)") })

        $this.Find("BtnRestoreCancel").Add_Click({ $self.Close() })

        $this.FitToContent($null)
        $null = $this.OpenAs($null)
        return $this.Result
    }
}
