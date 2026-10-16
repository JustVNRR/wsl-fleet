using module ..\BaseViewWpf.psm1
using module ..\..\..\ViewModels\CompactViewModel.psm1

class WpfCompactView : BaseViewWpf {
    hidden [object]$Vm = $null

    [object] Ask([string]$name) {
        $self = $this
        $this.Vm = [CompactViewModel]::new($name)
        $this.Title = "Compact instance"
        $this.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
        $this.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $this.ResizeMode = [System.Windows.ResizeMode]::NoResize
        $this.Load((Join-Path $PSScriptRoot "Compact.xaml"))
        $this.WearDefault()
        $this.Dress($null, 15)
        $this.DataContext = $this.Vm

        $this.Vm.DemandeFermeture = { param($result) $self.Result = $result; $self.Close() }
        $this.Add_ContentRendered({ $null = $this.Find("ChkArchive").Focus() })

        $this.Find("ChkArchive").Add_Checked({ param($source, $e) $self.Vm.SetArchiveFirst([bool]$source.IsChecked) })
        $this.Find("ChkArchive").Add_Unchecked({ param($source, $e) $self.Vm.SetArchiveFirst([bool]$source.IsChecked) })

        $this.Find("BtnGateCancel").Add_Click({ $self.Close() })

        $this.FitToContent($null)
        $null = $this.OpenAs($null)
        return $this.Result
    }
}
