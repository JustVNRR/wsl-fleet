using module ..\BaseViewWpf.psm1
using module ..\..\..\ViewModels\ErrorViewModel.psm1

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

        $this.Find("BtnErrorOk").Add_Click({ $self.Close() })

        $this.FitToContent($null)
        $null = $this.OpenAs($null)
        return $null
    }
}
