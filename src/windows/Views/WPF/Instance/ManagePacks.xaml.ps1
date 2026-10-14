# ==============================================================================
# MANAGEPACKS — LA VUE WPF
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewWpf.psm1
using module ..\..\..\ViewModels\ManagePacksViewModel.psm1

# La checklist, la fenêtre : le DataContext est le ManagePacksViewModel — les
# cases, les deux lignes du cli et APPLY se bindent en XAML. Ici, le strict
# nécessaire : le chargement, la fermeture sur Done, et le Dto rendu. Rien à
# choisir : Ask rend $null sans même ouvrir (une réponse, pas une annulation).
class WpfManagePacksView : BaseViewWpf {
    hidden [object]$Vm = $null

    [object] Ask([object]$packs, [string]$name) {
        $self = $this
        $this.Vm = [ManagePacksViewModel]::new($packs, $name)
        if ($this.Vm.Empty()) { return $null }

        $this.Title = "Packs"
        $this.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
        $this.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $this.ResizeMode = [System.Windows.ResizeMode]::NoResize
        $this.Load((Join-Path $PSScriptRoot "ManagePacks.xaml"))
        $this.WearDefault()
        $this.Dress($null, 15)
        $this.DataContext = $this.Vm

        $this.Vm.add_PropertyChanged({
            param($source, $e)
            if ("$($e.PropertyName)" -eq "Done") { $self.Close() }
        })

        $this.Find("BtnPacksCancel").Add_Click({ $self.Close() })

        $this.FitToContent($null)
        $null = $this.OpenAs($null)
        return $this.Vm.Result
    }
}
