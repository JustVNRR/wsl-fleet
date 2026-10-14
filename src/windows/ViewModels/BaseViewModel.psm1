# ==============================================================================
# LE SOCLE DES VIEWMODELS — LES DEUX CLASSES DE BASE
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout lui-même ce qu'il
# tire. Rien à tirer ici : ICommand et INotifyPropertyChanged vivent dans la
# bibliothèque de base de .NET (System.ObjectModel) — PAS dans WPF : le socle
# se charge partout, y compris au bac à sable, et se couvre sans fenêtre.
#
# PowerShell n'a PAS de mot-clé [event] (mesuré : refusé au parse) : un
# événement d'interface se pose à la main — add_/remove_ et une liste de
# poignées, l'événement se crie soi-même.

# Un ViewModel : sa base. L'état bindable se pose dans les enfants — une
# propriété = un champ caché + une ScriptProperty posée sur l'instance par
# AddProperty, qui se dit (mesuré : PowerShell n'a PAS d'accesseurs get/set
# sur les propriétés de classe, et une propriété nue ne notifie rien) — et
# chaque changement remonte ici.
class BaseViewModel : System.ComponentModel.INotifyPropertyChanged {
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

    # Une propriété bindable : WPF lit une ScriptProperty comme une propriété
    # (mesuré — le brouillon Gemini montrait des accesseurs get/set qui ne
    # parsent même pas). Le get et le set s'écrivent au site d'appel, field
    # caché et OnPropertyChanged compris. Les méthodes de la classe, elles,
    # touchent le FIELD et réclament — jamais la propriété (elle vit sur la
    # coquille extérieure, pas sur $this — mesuré).
    hidden [void] AddProperty([string]$name, [scriptblock]$getter, [scriptblock]$setter) {
        $this | Add-Member -MemberType ScriptProperty -Name $name -Value $getter -SecondValue $setter
    }

    # La vue d'un geste, par son nom, où qu'elle vive sous les vues : le
    # fichier importé (le guet ne trouve que le chargé — mesuré), puis le
    # type cherché à l'exécution — le ViewModel ne connaît pas le WPF.
    # Ask, ses arguments, et son retour, rien quand rien n'a été rendu.
    # Statique : aucun état à tenir, tous les ViewModels s'en servent.
    static [object] OpenFace([string]$viewsRoot, [string]$gesture, [object[]]$arguments) {
        try {
            $file = @(Get-ChildItem -Path $viewsRoot -Recurse -Filter "$gesture.xaml.ps1" -File -ErrorAction SilentlyContinue)[0]
            if ($file) { $null = Import-Module $file.FullName -ErrorAction SilentlyContinue }
        } catch { }

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

    # Une commande : les blocs reçoivent le ViewModel en paramètre — jamais
    # lus par nom (un bloc lu par nom à distance est nul, mesuré) — et sont
    # emballés pour la même raison. L'ordre : { param($vm) $vm.QuelqueChose() }.
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

# Une commande : ce qu'un bouton déclenche, et ce qui décide s'il est actif.
# Sans CommandManager (WPF seul le connaît — absent du socle exprès) : le
# ViewModel crie RaiseCanExecuteChanged quand un droit change, et WPF
# réinterroge. Le « je ne commande pas sans nom » de la pizza, en somme.
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
