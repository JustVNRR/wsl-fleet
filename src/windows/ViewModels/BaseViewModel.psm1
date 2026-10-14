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

# Un ViewModel : sa base. L'état bindable vit dans les enfants, en VRAIES
# propriétés de classe : WPF ne lit que le type .NET — une ScriptProperty
# posée par Add-Member vit côté PowerShell et reste invisible (mesuré : le
# gui ouvert vide, tout ce qui passait par elle muet). Le VM mute par Set —
# la propriété se pose PAR SON NOM et le cri suit ; les saisies de l'UI,
# que WPF n'écrit plus (liens à sens unique), passent par les méthodes Set*
# de l'enfant, relayées par la vue.
class BaseViewModel : System.ComponentModel.INotifyPropertyChanged {
    # La porte de fermeture — la « méthode 1 » : le ViewModel dit « j'ai
    # fini », la vue a posé ce qu'elle en fait (fermer). Le VM ne connaît
    # pas WPF : sa demande voyage par ici.
    [scriptblock]$DemandeFermeture = $null

    # La porte d'ouverture, du même bois : le ViewModel dit « ouvre la boîte
    # X », la vue a posé comment et où on la trouve. Le VM ne connaît ni le
    # nom des vues ni leur dossier.
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

    # « J'ai fini » — la demande de fermeture, la valeur comprise (le Result) :
    # la vue la reçoit DE la porte, elle n'a rien à relire après coup. Un
    # ViewModel sans Result (les Réglages) ferme avec rien.
    hidden [void] RequestClose() {
        if ($this.DemandeFermeture) {
            $value = $null
            $resultProp = $this.GetType().GetProperty("Result")
            if ($resultProp) { $value = $resultProp.GetValue($this) }
            & $this.DemandeFermeture $value
        }
    }

    # « Ouvre la boîte X » — la demande d'ouverture, si la vue en a posé une.
    hidden [object] OpenBox([string]$gesture, [object[]]$arguments) {
        if ($this.Ouverture) { return & $this.Ouverture $gesture $arguments }
        return $null
    }

    # La vue d'un geste — pour la porte d'ouverture que la vue pose. Publique,
    # par l'INSTANCE : le type de base n'a pas de nom hors de son module
    # (mesuré), et une closure de vue ne peut pas le nommer.
    [object] FindFace([string]$viewsRoot, [string]$gesture, [object[]]$arguments) {
        return [BaseViewModel]::OpenFace($viewsRoot, $gesture, $arguments)
    }

    # Une mutation d'une propriété bindable : la vraie propriété se pose par
    # son nom (mesuré : $this.$name écrit la propriété de la classe) et le
    # cri suit. Gardes et réactions restent au site d'appel — Set ne juge
    # pas.
    hidden [void] Set([string]$name, [object]$value) {
        $this.$name = $value
        $this.OnPropertyChanged($name)
    }

    # La vue d'un geste, par son nom, où qu'elle vive sous les vues : le type
    # cherché au guet d'assemblée à l'exécution. Appelée par les VUES
    # seulement (les portes d'ouverture qu'elles posent) — un ViewModel ne
    # nomme ni vue ni dossier. L'IMPORT des fichiers vit chez l'entrée : le
    # premier import lancé d'ici se mord la queue (mesuré — la vue chaîne
    # BaseViewModel, ce module même, et GetExportedTypeDefinitions s'appelle
    # cent mille fois : « Impossible de créer une nouvelle page de garde
    # pour la pile »). Ask, ses arguments, et son retour, rien quand rien n'a
    # été rendu. Statique : aucun état à tenir, tous les ViewModels s'en
    # servent.
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
