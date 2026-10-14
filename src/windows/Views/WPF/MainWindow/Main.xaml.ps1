# ==============================================================================
# LA FENÊTRE PRINCIPALE — LA VUE WPF
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewWpf.psm1

# Le home du gui — la fenêtre de l'appli : l'entête, le tableau, la bande, la
# ligne d'état. Elle vit tant qu'on ne la ferme pas : Ask pousse un cadre de
# dispatcher, pas un ShowDialog — elle est la racine, pas une boîte.
#
# GRAPHISME SEUL : le DataContext est le ViewModel — l'état et les commandes
# se bindent en XAML — et ce fichier ne garde que ce que WPF demande : le
# chargement, le cadre, le volet (chez le socle), le focus, Échap, le filet,
# le rhabillage sur le cri du ViewModel (Appearance), et LE BATTEMENT — un
# minuteur qui toppe Tick ; c'est le ViewModel qui regarde ses enfants de là.
class WpfMainView : BaseViewWpf {
    hidden [object]$Vm = $null
    hidden [object]$Beat = $null

    [string] Ask([object]$vm) {
        $self = $this
        $this.Vm = $vm

        $this.Title = "WSL Stack Manager"
        $this.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
        $this.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $this.MinHeight = 240
        $this.Load((Join-Path $PSScriptRoot "Main.xaml"))
        $this.Dress($null, 15)
        # Le socle la connaît : c'est derrière ELLE que les boîtes s'ouvrent —
        # elle s'efface le temps qu'elles vivent, et revient.
        [BaseViewWpf]::Main = $this
        $this.DataContext = $vm

        # Le graphisme suit l'état : la face se rhabille sur le cri du
        # ViewModel — c'est lui qui décide, c'est ici que ça se peint.
        $vm.add_PropertyChanged({
            param($source, $e)
            if ("$($e.PropertyName)" -in @("Variant", "Appearance")) { $self.Rewear() }
        })

        $this.Find("BtnQuit").Add_Click({ $self.Close() })

        # Échap ferme — sauf quand la main tape dans un champ.
        $this.Add_PreviewKeyDown({
            param($source, $e)
            if ($e.Key -eq [System.Windows.Input.Key]::Escape) {
                if ([System.Windows.Input.Keyboard]::FocusedElement -is [System.Windows.Controls.TextBox]) { return }
                $source.Close()
            }
        })

        # Le plafond suit l'écran où la fenêtre vit — relu au changement
        # d'écran et après chaque glissé, pas une fois pour toutes.
        $this.Add_DpiChanged({ $self.FitCeiling() })
        $this.Add_MouseLeftButtonUp({ $self.FitCeiling() })

        # Le filet : une exception du fil tue le processus — attrapée ici,
        # dite par le ViewModel, la fenêtre vit. Décroché à la sortie.
        $safetyNet = [System.Windows.Threading.DispatcherUnhandledExceptionEventHandler]{
            param($source, $e)
            $e.Handled = $true
            $where = ""
            if ($e.Exception.ErrorRecord -and $e.Exception.ErrorRecord.ScriptStackTrace) {
                $where = " @ " + (($e.Exception.ErrorRecord.ScriptStackTrace -split "`n")[0] -replace '^\s+', '')
            }
            try { $self.Vm.Fail("A drawing failed: $($e.Exception.Message)$where") } catch { }
        }
        $this.Dispatcher.Add_UnhandledException($safetyNet)

        # La racine se montre — le cadre de l'appli, pas une boîte : fermer la
        # fenêtre le fait sortir.
        $frame = [System.Windows.Threading.DispatcherFrame]::new()
        $this.Add_Closed({ $frame.Continue = $false })

        $this.Rewear()

        # LE BATTEMENT : un minuteur, priorité d'entrée (une priorité de fond
        # s'affamait sous la pompe, mesuré) — le ViewModel regarde ses
        # ouvriers de là.
        $this.Beat = [System.Windows.Threading.DispatcherTimer]::new([System.Windows.Threading.DispatcherPriority]::Input)
        $this.Beat.Interval = [TimeSpan]::FromMilliseconds(400)
        $this.Beat.Tag = $this
        $this.Beat.Add_Tick({ param($s, $e) $s.Tag.Vm.Tick() })
        $this.Beat.Start()

        try {
            $this.Show()
            # Montrée : elle a un écran, et le plafond suit celui-là.
            $this.FitCeiling()
            # Le lancement a laissé la console devant — la fenêtre était faite
            # par son processus : elle demande le premier plan.
            $null = $this.Activate()
            $this.Topmost = $true
            $this.Topmost = $false
            # Échap a besoin d'un foyer pour voyager — la liste le prend.
            $null = $this.Find("LstInstances").Focus()
            [System.Windows.Threading.Dispatcher]::PushFrame($frame)
        } finally {
            $this.Dispatcher.Remove_UnhandledException($safetyNet)
            # Rien de ce lancement ne reste accroché : le minuteur s'arrête,
            # les statiques se vident.
            if ($this.Beat) { $this.Beat.Stop() }
            [BaseViewWpf]::Main = $null
            [BaseViewWpf]::Depth = 0
        }
        return "closed"
    }

    # La face : le thème porté par le ViewModel — le dictionnaire remplacé,
    # le bouton mis à jour.
    hidden [void] Rewear() {
        $this.WearTheme([BaseViewWpf]::Assets, "$($this.Vm.ColourSet)", "$($this.Vm.Variant)")
        $this.Dress($null, 15)
        $this.UpdateThemeButton()
    }

    # Le bouton du thème : éteint quand le thème n'a pas de version claire, et
    # son icône montre ce qu'un clic apporte — un soleil tant qu'il fait
    # sombre, une lune tant qu'il fait clair.
    hidden [void] UpdateThemeButton() {
        $button = $this.Find("BtnTheme")
        $button.IsEnabled = $this.ThemeHasLight([BaseViewWpf]::Assets, "$($this.Vm.ColourSet)")
        $light = "$($this.Vm.Variant)" -eq "Light"
        $icon = if ($light) { 0xF186 } else { 0xF185 }
        $button.Content = [string][char]$icon
        $button.ToolTip = if ($light) { "Switch to dark" } else { "Switch to light" }
    }

    # Le plafond suit l'écran où la fenêtre est vraiment — quatre lignes de
    # haut sous elle ; passé ça, la liste défile dedans.
    hidden [void] FitCeiling() {
        $area = $this.GetScreenWorkingArea($this)
        if ($area) {
            $this.MaxHeight = [Math]::Max(360, [int]$area.Height - 40)
        } else {
            $this.MaxHeight = [Math]::Max(360, [System.Windows.SystemParameters]::WorkArea.Height - 40)
        }
    }
}
