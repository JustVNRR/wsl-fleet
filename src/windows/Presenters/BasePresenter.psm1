# ==============================================================================
# LE PRESENTER — LA BASE
# ==============================================================================
# Ce que les presenters partagent : la résolution des vues. Une vue est un
# fichier du même nom que le geste, dont la classe porte le préfixe du type
# d'UI (Cli/Wpf) — et elle se cherche sous
#
#   Views\<ViewType>\<Presenter>\        le dossier du presenter
#   Views\<ViewType>\<Presenter>\shared\ une vue partagée par ses gestes
#   Views\<ViewType>\shared\             une vue commune aux presenters —
#                                        la vue d'erreur y vit
#
# Le fichier est importé au premier appel, la classe trouvée parmi les types
# chargés et instanciée sans état. Un fichier absent, ou une classe absente,
# est une faute d'installation : elle jette, fort — et la vue d'erreur,
# commune, peint le refus de n'importe quel geste.
#
# La carte injectable : un banc pose ses fausses vues dans Views, par nom de
# geste — GetView la consulte AVANT le disque, et rien d'autre ne change. Un
# presenter mène SA vue : il ordonne, il lit les réponses, il rend
# l'ActionResult — la vue ne fait qu'afficher.
class BasePresenter {
    hidden [string]$ViewsRoot
    hidden [string]$ViewType
    hidden [string]$ViewFolder
    hidden [hashtable]$Loaded = @{}

    # La carte des fausses vues, pour les bancs — vide à l'ordinaire.
    [hashtable]$Views = @{}

    BasePresenter([string]$viewsRoot, [string]$viewType, [string]$viewFolder) {
        $this.ViewsRoot = $viewsRoot
        $this.ViewType = $viewType
        $this.ViewFolder = $viewFolder
    }

    # La vue d'un geste, née ici : la carte d'abord, le disque ensuite.
    hidden [object] GetView([string]$gesture) {
        if ($this.Views.ContainsKey($gesture)) { return $this.Views[$gesture] }

        $this.ImportView($gesture)

        $prefix = $this.ViewType.Substring(0, 1).ToUpper() + $this.ViewType.Substring(1).ToLower()
        $className = "$prefix$gesture" + "View"

        # Pas de locale nommée $viewType : une méthode de classe refuse une
        # locale qui porte le nom d'une propriété (mesuré).
        $found = $null
        foreach ($assembly in [AppDomain]::CurrentDomain.GetAssemblies()) {
            try { $found = @($assembly.GetTypes() | Where-Object { $_.Name -eq $className })[0] } catch { }
            if ($found) { break }
        }
        if (-not $found) {
            throw "No $($this.ViewType) view class '$className' for '$gesture'."
        }

        return $found::new()
    }

    # Le fichier de la vue, importé au premier appel — le dossier du
    # presenter, puis son shared\, puis le shared\ du type d'UI. La vue du
    # cli est un XX.psm1 ; celle du WPF est la paire XX.xaml (le dessin) +
    # XX.xaml.ps1 (la classe) — le fichier cherché est le code.
    hidden [void] ImportView([string]$gesture) {
        if ($this.Loaded.ContainsKey($gesture)) { return }

        $typeRoot = Join-Path $this.ViewsRoot $this.ViewType
        $folders = @(
            (Join-Path $typeRoot $this.ViewFolder),
            (Join-Path (Join-Path $typeRoot $this.ViewFolder) "shared"),
            (Join-Path $typeRoot "shared")
        )
        $modulePath = ""
        foreach ($folder in $folders) {
            foreach ($name in @("$gesture.psm1", "$gesture.xaml.ps1")) {
                $candidate = Join-Path $folder $name
                if (Test-Path $candidate) { $modulePath = $candidate; break }
            }
            if ($modulePath) { break }
        }
        if (-not $modulePath) {
            throw "No $($this.ViewType) view for '$gesture' under '$typeRoot'."
        }
        $null = Import-Module $modulePath -Force
        $this.Loaded[$gesture] = $true
    }

    # Le refus d'un geste, peint par la vue d'erreur commune — une par UI.
    hidden [void] ShowFailure([string]$message) {
        $view = $this.GetView("Error")
        $view.Show($message)
    }
}
