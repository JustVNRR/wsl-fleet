using module ..\BaseViewWpf.psm1
using module ..\..\..\ViewModels\PackDuplicateViewModel.psm1

class WpfPackDuplicateView : BaseViewWpf {

    hidden [object]$Vm = $null

    [object] Ask([string]$source, [string]$description, [string[]]$taken) {
        $self = $this
        $this.Vm = [PackDuplicateViewModel]::new($source, $description, $taken)

        $this.Title = "Wsl Fleet"
        $this.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
        $this.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $this.ResizeMode = [System.Windows.ResizeMode]::NoResize
        $this.Load((Join-Path $PSScriptRoot "PackDuplicate.xaml"))
        $this.WearDefault()
        $this.Dress($null, 15)
        $this.DataContext = $this.Vm

        $this.Vm.DemandeFermeture = { param($result) $self.Result = $result; $self.Close() }

        $this.Add_ContentRendered({ $null = $self.Find("TxtDupName").Focus(); $self.Find("TxtDupName").SelectAll() })

        $this.Find("TxtDupName").Add_TextChanged({ param($box, $e) $self.Vm.SetName("$($box.Text)") })
        $this.Find("TxtDupDescription").Add_TextChanged({ param($box, $e) $self.Vm.SetDescription("$($box.Text)") })
        $this.Find("BtnDupCancel").Add_Click({ $self.Close() })

        $this.FitToContent($null)
        $null = $this.OpenAs($null)
        return $this.Result
    }
}
