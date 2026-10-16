using module ..\BaseViewWpf.psm1
using module ..\..\..\ViewModels\RecipeNameViewModel.psm1

class WpfRecipeNameView : BaseViewWpf {

    hidden [object]$Vm = $null

    [object] Ask() {
        $self = $this
        $this.Vm = [RecipeNameViewModel]::new()

        $this.Title = "Wsl Fleet"
        $this.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
        $this.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $this.ResizeMode = [System.Windows.ResizeMode]::NoResize
        $this.Load((Join-Path $PSScriptRoot "RecipeName.xaml"))
        $this.WearDefault()
        $this.Dress($null, 15)
        $this.DataContext = $this.Vm

        $this.Vm.DemandeFermeture = { param($result) $self.Result = $result; $self.Close() }

        $this.Vm.add_PropertyChanged({
            param($source, $e)
            if ("$($e.PropertyName)" -eq "NameError") { $self.ShowError("GuiNameError", "$($source.NameError)") }
        })

        $this.Add_ContentRendered({ $null = $self.Find("TxtRecipeName").Focus() })

        $this.Find("TxtRecipeName").Add_TextChanged({ param($box, $e) $self.Vm.SetName("$($box.Text)") })
        $this.Find("BtnRecipeCancel").Add_Click({ $self.Close() })

        $this.FitToContent($null)
        $null = $this.OpenAs($null)
        return $this.Result
    }
}
