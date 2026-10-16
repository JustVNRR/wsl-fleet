
class BaseViewModel : System.ComponentModel.INotifyPropertyChanged {
    [scriptblock]$DemandeFermeture = $null

    [scriptblock]$Ouverture = $null

    hidden [System.Collections.Generic.List[System.ComponentModel.PropertyChangedEventHandler]]$Handlers

    BaseViewModel() {
        $this.Handlers = [System.Collections.Generic.List[System.ComponentModel.PropertyChangedEventHandler]]::new()
    }

    [void] add_PropertyChanged([System.ComponentModel.PropertyChangedEventHandler]$handler) {
        $this.Handlers.Add($handler)
    }

    [void] remove_PropertyChanged([System.ComponentModel.PropertyChangedEventHandler]$handler) {
        $null = $this.Handlers.Remove($handler)
    }

    hidden [void] OnPropertyChanged([string]$name) {
        foreach ($handler in $this.Handlers.ToArray()) {
            $handler.Invoke($this, [System.ComponentModel.PropertyChangedEventArgs]::new($name))
        }
    }

    hidden [void] RequestClose() {
        if ($this.DemandeFermeture) {
            $value = $null
            $resultProp = $this.GetType().GetProperty("Result")
            if ($resultProp) { $value = $resultProp.GetValue($this) }
            & $this.DemandeFermeture $value
        }
    }

    hidden [object] OpenBox([string]$gesture, [object[]]$arguments) {
        if ($this.Ouverture) { return & $this.Ouverture $gesture $arguments }
        return $null
    }

    [object] FindFace([string]$viewsRoot, [string]$gesture, [object[]]$arguments) {
        return [BaseViewModel]::OpenFace($viewsRoot, $gesture, $arguments)
    }

    hidden [void] Set([string]$name, [object]$value) {
        $this.$name = $value
        $this.OnPropertyChanged($name)
    }

    static [object] OpenFace([string]$viewsRoot, [string]$gesture, [object[]]$arguments) {
        $wanted = "Wpf${gesture}View"
        $face = $null
        foreach ($assembly in [AppDomain]::CurrentDomain.GetAssemblies()) {
            try { $face = @($assembly.GetTypes() | Where-Object { $_.Name -eq $wanted })[0] } catch { }
            if ($face) { break }
        }
        if (-not $face) { return $null }

        $view = $face::new()
        $invoked = @($view.Ask.Invoke(@($arguments)))
        if ($invoked.Count -eq 0) { return $null }
        return $invoked[0]
    }

    hidden [RelayCommand] NewCommand([scriptblock]$run) {
        return $this.NewCommand($run, $null)
    }

    hidden [RelayCommand] NewCommand([scriptblock]$run, [scriptblock]$allows) {
        $vm = $this
        $runBlock = $run
        $allowBlock = $allows
        $runner = { param($parameter) & $runBlock $vm $parameter }.GetNewClosure()
        $gate = $null
        if ($allowBlock) { $gate = { param($parameter) [bool](& $allowBlock $vm $parameter) }.GetNewClosure() }
        return [RelayCommand]::new($runner, $gate)
    }
}

class RelayCommand : System.Windows.Input.ICommand {
    hidden [scriptblock]$Run
    hidden [scriptblock]$Allows
    hidden [System.Collections.Generic.List[System.EventHandler]]$Watchers

    RelayCommand([scriptblock]$run) {
        $this.Run = $run
        $this.Allows = $null
        $this.Watchers = [System.Collections.Generic.List[System.EventHandler]]::new()
    }

    RelayCommand([scriptblock]$run, [scriptblock]$allows) {
        $this.Run = $run
        $this.Allows = $allows
        $this.Watchers = [System.Collections.Generic.List[System.EventHandler]]::new()
    }

    [bool] CanExecute([object]$parameter) {
        if (-not $this.Allows) { return $true }
        return [bool](& $this.Allows $parameter)
    }

    [void] Execute([object]$parameter) {
        & $this.Run $parameter
    }

    [void] add_CanExecuteChanged([System.EventHandler]$handler) {
        $this.Watchers.Add($handler)
    }

    [void] remove_CanExecuteChanged([System.EventHandler]$handler) {
        $null = $this.Watchers.Remove($handler)
    }

    [void] RaiseCanExecuteChanged() {
        foreach ($handler in $this.Watchers.ToArray()) {
            $handler.Invoke($this, [System.EventArgs]::Empty)
        }
    }
}
