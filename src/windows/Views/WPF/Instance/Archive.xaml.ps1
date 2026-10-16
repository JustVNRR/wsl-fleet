using module ..\BaseViewWpf.psm1
using module ..\..\..\ViewModels\ArchiveViewModel.psm1

class WpfArchiveView : BaseViewWpf {

    hidden [object]$Vm = $null

    [object] Ask([string]$name, [object[]]$rows) {
        $self = $this
        $this.Vm = [ArchiveViewModel]::new($name, $rows)
        $this.Title = "Archive instance"
        $this.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
        $this.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $this.ResizeMode = [System.Windows.ResizeMode]::NoResize
        $this.Load((Join-Path $PSScriptRoot "Archive.xaml"))
        $this.WearDefault()
        $this.Dress($null, 15)
        $this.DataContext = $this.Vm

        $this.Vm.DemandeFermeture = { param($result) $self.Result = $result; $self.Close() }

        $this.Find("BtnArchiveCancel").Add_Click({ $self.Close() })

        $this.FitToContent($null)
        $null = $this.OpenAs($null)
        return $this.Result
    }
}
