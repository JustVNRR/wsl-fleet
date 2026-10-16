using module ..\BaseViewWpf.psm1

class WpfMainView : BaseViewWpf {

    hidden [object]$Vm = $null
    hidden [object]$Beat = $null

    [string] Ask([object]$vm) {
        $self = $this
        $this.Vm = $vm

        $this.Title = "Wsl Fleet Manager"
        $this.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
        $this.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $this.MinHeight = 240
        $this.Load((Join-Path $PSScriptRoot "Main.xaml"))
        [BaseViewWpf]::Main = $this
        $this.DataContext = $vm

        $vm.add_PropertyChanged({
            param($source, $e)
            if ("$($e.PropertyName)" -in @("Variant", "Appearance")) { $self.Rewear() }
        })

        $this.Find("BtnQuit").Add_Click({ $self.Close() })

        $this.Add_PreviewKeyDown({
            param($source, $e)
            if ($e.Key -eq [System.Windows.Input.Key]::Escape) {
                if ([System.Windows.Input.Keyboard]::FocusedElement -is [System.Windows.Controls.TextBox]) { return }
                $source.Close()
            }
        })

        $this.Add_DpiChanged({ $self.FitCeiling() })
        $this.Add_MouseLeftButtonUp({ $self.FitCeiling() })

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

        $frame = [System.Windows.Threading.DispatcherFrame]::new()
        $this.Add_Closed({ $frame.Continue = $false })

        $this.Rewear()

        $this.Beat = [System.Windows.Threading.DispatcherTimer]::new([System.Windows.Threading.DispatcherPriority]::Input)
        $this.Beat.Interval = [TimeSpan]::FromMilliseconds(400)
        $this.Beat.Tag = $this
        $this.Beat.Add_Tick({ param($s, $e) $s.Tag.Vm.Tick() })
        $this.Beat.Start()

        try {
            $this.Show()
            $this.FitCeiling()
            $null = $this.Activate()
            $this.Topmost = $true
            $this.Topmost = $false
            $null = $this.Find("LstInstances").Focus()
            [System.Windows.Threading.Dispatcher]::PushFrame($frame)
        } finally {
            $this.Dispatcher.Remove_UnhandledException($safetyNet)
            if ($this.Beat) { $this.Beat.Stop() }
            [BaseViewWpf]::Main = $null
            [BaseViewWpf]::Depth = 0
        }
        return "closed"
    }

    hidden [void] Rewear() {
        $this.WearTheme([BaseViewWpf]::Assets, "$($this.Vm.ColourSet)", "$($this.Vm.Variant)")
        $this.Dress($null, 15)
        $this.UpdateThemeButton()
    }

    hidden [void] UpdateThemeButton() {
        $button = $this.Find("BtnTheme")
        $button.IsEnabled = $this.ThemeHasLight([BaseViewWpf]::Assets, "$($this.Vm.ColourSet)")
        $light = "$($this.Vm.Variant)" -eq "Light"
        $icon = if ($light) { 0xF186 } else { 0xF185 }
        $button.Content = [string][char]$icon
        $button.ToolTip = if ($light) { "Switch to dark" } else { "Switch to light" }
    }

    hidden [void] FitCeiling() {
        $area = $this.GetScreenWorkingArea($this)
        if ($area) {
            $this.MaxHeight = [Math]::Max(360, [int]$area.Height - 40)
        } else {
            $this.MaxHeight = [Math]::Max(360, [System.Windows.SystemParameters]::WorkArea.Height - 40)
        }
    }
}
