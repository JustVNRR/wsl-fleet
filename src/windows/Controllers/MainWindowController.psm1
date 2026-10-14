# ==============================================================================
# LE CONTRÔLEUR DE LA FENÊTRE
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce type qu'il a tiré
# lui-même.
using module .\ActionResult.psm1
using module .\BaseController.psm1
using module ..\Service\WpfService.psm1
using module ..\Service\PackCatalogService.psm1
using module ..\Service\FleetService.psm1
using module ..\Service\InstanceService.psm1
using module ..\Dto\WpfDto.psm1

# Le home du gui — la fenêtre (son nom dit son objet) ; le cli n'a pas de
# jumeau : son home est le menu, et un menu distribue, il ne fait rien. La
# fenêtre : le tableau (Main) et son Réglages — celle d'aujourd'hui (root,
# police, thème, catalogue, CLOSE) —, qui touche les mondes. Le contrôleur
# tient les services qu'elles demandent — « le contrôleur appelle le(s)
# service(s) » : la face (WpfService), le catalogue (PackCatalogService), la
# racine (FleetService), l'index des instances (InstanceService — les lignes
# du tableau). Ses vues sont sous Views\<ViewType>\MainWindow\ : XX.xaml (le
# dessin) + XX.xaml.ps1 (la classe).
#
# La fenêtre applique EN DIRECT (elle échange son dictionnaire sous elle) ;
# à la fermeture le thème complet revient, et le contrôleur le passe ENTIER
# au service — les quatre portes à chaque fois : changer tout est plus simple
# à tenir qu'un diff (son choix). Un dossier d'arrivée confirmé : le
# Réglages REND la racine ; c'est la fenêtre principale qui l'envoie à
# l'ouvrier (Runners\MigrateRunner.ps1) — sa bande suit le voyage.
class MainWindowController : BaseController {
    hidden [WpfService]$Service
    hidden [PackCatalogService]$Catalogue
    hidden [FleetService]$Fleet
    hidden [InstanceService]$Instance
    hidden [string]$AssetsDir

    MainWindowController([WpfService]$service, [PackCatalogService]$catalogue, [FleetService]$fleet,
                         [InstanceService]$instance, [string]$assetsDir, [string]$viewsRoot, [string]$viewType) : base($viewsRoot, $viewType, "MainWindow") {
        $this.Service = $service
        $this.Catalogue = $catalogue
        $this.Fleet = $fleet
        $this.Instance = $instance
        $this.AssetsDir = $assetsDir
    }

    # La fenêtre — le home du gui, qui vit jusqu'à sa fermeture. Le contrôleur
    # lit ce qu'elle affiche — les lignes (l'index de l'instance), la racine,
    # le look — et lui lie ses propres portes : la relecture (l'index relu),
    # la racine, le Réglages, la version claire/sombre. Les portes des GESTES
    # de ligne arrivent de l'entrée, qui seule tient tous les contrôleurs —
    # la fenêtre ne sait pas d'où elles viennent, et aux gestes longs elles
    # rendent leur porte : c'est la fenêtre qui mène l'ouvrier. La vue vit sa
    # vie : le geste rend quand elle se ferme.
    [ActionResult] Main([object]$gestures) {
        $view = $this.GetView("Main")
        try {
            $rows = @($this.Instance.GetAll())
            $root = $this.Fleet.GetRoot()
            $theme = $this.Service.GetTheme()
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Main : $($_.Exception.Message)")
        }

        $doors = [ordered]@{
            Refresh    = $this.Instance.GetAll
            Root       = $this.Fleet.GetRoot
            Settings   = $this.Settings
            SetVariant = $this.Service.SetVariant
            ReRoot     = $this.ReRoot
        }
        if ($gestures) {
            foreach ($property in $gestures.PSObject.Properties) { $doors[$property.Name] = $property.Value }
        }

        $view.Ask($rows, $root, $theme, [PSCustomObject]$doors)
        return [ActionResult]::Ok("Main : closed")
    }

    # Le monde en mémoire suit la racine écrite : après un migrate, les
    # services re-pointent avant que la liste ne se relise — sinon elle lit
    # l'ancienne pour toujours (vécu : la restauration invisible jusqu'au
    # redémarrage). La racine est RELUE ici, pas reçue : le voyage l'a
    # peut-être changée.
    [void] ReRoot() {
        $root = $this.Fleet.GetRoot()
        $this.Fleet.ReRoot($root)
        $this.Instance.ReRoot($root)
    }

    # Le look en cours — lu au service, rien à peindre de plus : les fenêtres
    # qui le montrent le reçoivent en donnée.
    [ActionResult] GetTheme() {
        try {
            $theme = $this.Service.GetTheme()
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("GetTheme : $($_.Exception.Message)")
        }
        return [ActionResult]::Ok("GetTheme : font '$($theme.FontFamily)' at $($theme.FontSize), $($theme.ColorTheme) ($($theme.Variant))")
    }

    # La fenêtre du Réglages : le contrôleur lit tout ce que ses listes
    # affichent — le look, les thèmes du dossier, les familles, le catalogue,
    # la racine — et lie les portes du service (les polices et les thèmes
    # s'écrivent, un pack se duplique ou s'efface en direct) : la vue n'en
    # sait pas plus. Le dossier d'arrivée choisi est RENDU tel quel : c'est
    # la fenêtre principale qui le porte au migrate, pas ce geste.
    [object] Settings() {
        $view = $this.GetView("Settings")
        try {
            $theme = $this.Service.GetTheme()
            $themes = @($this.Service.GetColorThemes())
            $fonts = @($this.Service.GetFontChoices())
            $packs = @($this.Catalogue.GetAllPacks())
            $root = $this.Fleet.GetRoot()

            $doors = [PSCustomObject]@{
                UploadFont    = $this.Service.UploadFont
                UploadTheme   = $this.Service.UploadTheme
                DeleteTheme   = $this.Service.DeleteTheme
                ExportTheme   = $this.Service.ExportTheme
                OpenTheme     = $this.Service.OpenTheme
                PackOpen      = $this.Catalogue.OpenPackFolder
                PackDuplicate = $this.Catalogue.CreatePack
                PackDelete    = $this.Catalogue.DeletePack
                PackRefresh   = $this.Catalogue.GetAllPacks
            }
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Settings : $($_.Exception.Message)")
        }

        $picked = $view.Ask($theme, $themes, $fonts, $packs, $root, $this.AssetsDir, $doors)
        if ($null -eq $picked) {
            if ($this.ViewType -eq "WPF") { return $null }
            return [ActionResult]::Ok("Settings : cancelled")
        }

        try {
            $this.Service.SetFontFamily($picked.FontFamily)
            $this.Service.SetFontSize($picked.FontSize)
            $this.Service.SetColorTheme($picked.ColorTheme)
            $this.Service.SetVariant($picked.Variant)
        } catch {
            $this.ShowFailure($_.Exception.Message)
            return [ActionResult]::Nok("Settings : $($picked.FontFamily)/$($picked.ColorTheme) - $($_.Exception.Message)")
        }

        # Le dossier d'arrivée — quand il y en a un — part avec le reste : la
        # fenêtre principale le portera au migrate.
        if ($this.ViewType -eq "WPF") { return $picked }

        $message = "Settings : font '$($picked.FontFamily)' at $($picked.FontSize), $($picked.ColorTheme) ($($picked.Variant))"
        if ($picked.NewRoot) { $message = "$message - the fleet moves to '$($picked.NewRoot)'" }
        return [ActionResult]::Ok($message)
    }
}
