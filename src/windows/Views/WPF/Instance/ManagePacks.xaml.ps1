# ==============================================================================
# MANAGEPACKS — LA VUE WPF
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewWpf.psm1
using module ..\..\..\ViewModels\ManagePacksViewModel.psm1

# La checklist, la fenêtre : le DataContext est le ManagePacksViewModel — les
# cases, les deux lignes du cli et APPLY se bindent en XAML. Ici, le strict
# nécessaire : le chargement, la porte de fermeture, et le Dto rendu. Rien à
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

        # La porte de fermeture — METHODE 1 : le ViewModel dit « j'ai fini »,
        # la vue ferme.
        $this.Vm.DemandeFermeture = { $self.Close() }

        # Les cases se construisent à la main — des chaînes, jamais un
        # gabarit d'items (muet sur nos objets, mesuré). Le relais ROUTÉ
        # attrape chaque bascule (le même que l'ancien tableau utilisait
        # pour les clics) et la porte au ViewModel de la ligne, qui recompte.
        $toggled = [System.Windows.RoutedEventHandler]{
            param($source, $e)
            $box = $e.OriginalSource
            if ($box -is [System.Windows.Controls.Primitives.ToggleButton] -and $box.Tag -is [PackRowViewModel]) {
                $box.Tag.SetChecked([bool]$box.IsChecked)
            }
        }
        $this.AddHandler([System.Windows.Controls.Primitives.ToggleButton]::CheckedEvent, $toggled)
        $this.AddHandler([System.Windows.Controls.Primitives.ToggleButton]::UncheckedEvent, $toggled)

        $panel = $this.Find("PnlPacks")
        foreach ($row in @($this.Vm.PackRows)) {
            $box = [System.Windows.Controls.CheckBox]::new()
            $text = [System.Windows.Controls.TextBlock]::new()
            $text.Text = "$($row.Label)"
            $text.TextWrapping = [System.Windows.TextWrapping]::Wrap
            $box.Content = $text
            $box.Tag = $row
            $box.Margin = [System.Windows.Thickness]::new(0, 3, 0, 3)
            $box.IsChecked = [bool]$row.Checked
            $null = $panel.Children.Add($box)
        }

        $this.Find("BtnPacksCancel").Add_Click({ $self.Close() })

        $this.FitToContent($null)
        $null = $this.OpenAs($null)
        return $this.Vm.Result
    }
}
