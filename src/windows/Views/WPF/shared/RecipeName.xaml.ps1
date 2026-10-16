# ==============================================================================
# A RECIPE'S NAME - THE WPF VIEW
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewWpf.psm1
using module ..\..\..\ViewModels\RecipeNameViewModel.psm1

# The + popup: one name, the rule, the red line when it refuses - APPLY hands
# the name back, Cancel hands nothing.
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

        # La porte de fermeture — METHODE 1 : le ViewModel dit « j'ai fini »,
        # la vue ferme.
        $this.Vm.DemandeFermeture = { param($result) $self.Result = $result; $self.Close() }

        $this.Add_ContentRendered({ $null = $self.Find("TxtRecipeName").Focus() })

        # Les liens sont à sens unique : les saisies sont relayées au
        # ViewModel.
        $this.Find("TxtRecipeName").Add_TextChanged({ param($box, $e) $self.Vm.SetName("$($box.Text)") })
        $this.Find("BtnRecipeCancel").Add_Click({ $self.Close() })

        $this.FitToContent($null)
        $null = $this.OpenAs($null)
        return $this.Result
    }
}
