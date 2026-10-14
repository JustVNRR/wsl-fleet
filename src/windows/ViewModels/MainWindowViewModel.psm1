# ==============================================================================
# LA FENÊTRE PRINCIPALE — LE VIEWMODEL
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout lui-même ce qu'il
# tire. Rien du WPF ici — que du PowerShell et des services : le ViewModel se
# charge et se teste sans fenêtre.
#
# Il porte l'écran : l'état bindable (les lignes, la racine, la ligne d'état,
# la bande) et les commandes (le rafraîchissement, l'entête, les gestes des
# lignes). Il a les SERVICES en main — c'est lui l'intermédiaire ; les portes
# liées de l'ancien monde n'ont plus lieu d'être.
#
# Les longues : le dialogue d'abord (la vue du geste, résolue par son nom au
# guet d'assemblée — le ViewModel ne connaît pas le WPF), puis l'ouvrier dans
# un processus à part — caché pour les six longs (journal et sentinelle),
# visible pour les packs, la naissance et le migrate. Le battement est chez
# la vue : un minuteur qui toppe Tick — le ViewModel regarde l'enfant de là.
using module .\BaseViewModel.psm1
using module ..\Tools\Helpers.psm1

# Une ligne du tableau : ce qu'elle montre, et si elle travaille. Le petit
# ruban remplace ses icônes pendant qu'un geste court.
class InstanceRowViewModel : BaseViewModel {
    hidden [bool]$_busy = $false
    [string]$Name = ""
    [string]$Size = ""
    [bool]$IsArchive = $false

    InstanceRowViewModel([object]$row) {
        $this.Name = "$($row.Name)"
        $this.Size = Format-Size ([double]$row.Size)
        $this.IsArchive = [bool]$row.IsArchive
        $this.AddProperty("IsBusy", { return $this._busy }, {
            param($value)
            if ($this._busy -ne $value) { $this._busy = [bool]$value; $this.OnPropertyChanged("IsBusy") }
        })
    }

    [void] Spin([bool]$on) {
        $this._busy = $on
        $this.OnPropertyChanged("IsBusy")
    }
}

# La fenêtre de l'appli : son état, ses commandes. Le ctor ne touche à rien
# qui vive sur le disque — le chargement est une méthode, la vue l'appelle
# quand elle est prête.
class MainWindowViewModel : BaseViewModel {
    hidden [object]$_instance
    hidden [object]$_fleet
    hidden [object]$_wpf
    hidden [object]$_catalogue
    hidden [string]$_assets = ""
    hidden [string]$_runners = ""
    hidden [string]$_views = ""

    hidden [object[]]$_rows = @()
    hidden [string]$_root = ""
    hidden [string]$_status = "Ready."
    hidden [bool]$_alert = $false
    hidden [bool]$_busy = $false
    hidden [string]$_colourSet = ""
    hidden [string]$_variant = "Dark"

    # Le guet : l'ouvrier caché (le journal le dit), et la console visible.
    hidden [object]$Worker = $null
    hidden [string]$WorkerVerb = ""
    hidden [string]$WorkerName = ""
    hidden [int]$Ticks = 0
    hidden [object]$Console = $null

    [System.Windows.Input.ICommand]$RefreshCommand
    [System.Windows.Input.ICommand]$AddCommand
    [System.Windows.Input.ICommand]$SettingsCommand
    [System.Windows.Input.ICommand]$ThemeCommand
    [System.Windows.Input.ICommand]$OpenCommand
    [System.Windows.Input.ICommand]$EditCommand
    [System.Windows.Input.ICommand]$AppearanceCommand
    [System.Windows.Input.ICommand]$DuplicateCommand
    [System.Windows.Input.ICommand]$ArchiveCommand
    [System.Windows.Input.ICommand]$CompactCommand
    [System.Windows.Input.ICommand]$RemoveCommand
    [System.Windows.Input.ICommand]$RestoreCommand
    [System.Windows.Input.ICommand]$DeleteArchiveCommand

    MainWindowViewModel([object]$instanceService, [object]$fleetService, [object]$wpfService,
                        [object]$packCatalog, [string]$assetsDir, [string]$runnersDir, [string]$viewsRoot) {
        $this._instance = $instanceService
        $this._fleet = $fleetService
        $this._wpf = $wpfService
        $this._catalogue = $packCatalog
        $this._assets = $assetsDir
        $this._runners = $runnersDir
        $this._views = $viewsRoot

        try {
            $look = $this._wpf.GetTheme()
            $this._colourSet = "$($look.ColorTheme)"
            $this._variant = if ("$($look.Variant)") { "$($look.Variant)" } else { "Dark" }
        } catch { }

        $this.AddProperty("Rows", { return $this._rows }, {
            param($value)
            $this._rows = @($value)
            $this.OnPropertyChanged("Rows")
        })
        $this.AddProperty("Root", { return $this._root }, {
            param($value)
            if ($this._root -ne $value) { $this._root = "$value"; $this.OnPropertyChanged("Root") }
        })
        $this.AddProperty("Status", { return $this._status }, {
            param($value)
            if ($this._status -ne $value) { $this._status = "$value"; $this.OnPropertyChanged("Status") }
        })
        $this.AddProperty("Alert", { return $this._alert }, {
            param($value)
            if ($this._alert -ne $value) { $this._alert = [bool]$value; $this.OnPropertyChanged("Alert") }
        })
        $this.AddProperty("Busy", { return $this._busy }, {
            param($value)
            if ($this._busy -ne $value) { $this._busy = [bool]$value; $this.OnPropertyChanged("Busy"); $this.OnPropertyChanged("Free") }
        })
        # Le miroir de Busy : WPF n'a pas d'inverseur, les mains liées se
        # bindent sur Free.
        $this.AddProperty("Free", { return (-not $this._busy) }, { param($value) })
        $this.AddProperty("ColourSet", { return $this._colourSet }, {
            param($value)
            if ($this._colourSet -ne $value) { $this._colourSet = "$value"; $this.OnPropertyChanged("ColourSet") }
        })
        $this.AddProperty("Variant", { return $this._variant }, {
            param($value)
            if ($this._variant -ne $value) { $this._variant = "$value"; $this.OnPropertyChanged("Variant") }
        })

        $this.RefreshCommand = $this.NewCommand({ param($vm) $vm.Load() })
        $this.AddCommand = $this.NewCommand({ param($vm) $vm.Add() })
        $this.SettingsCommand = $this.NewCommand({ param($vm) $vm.Settings() })
        $this.ThemeCommand = $this.NewCommand({ param($vm) $vm.ToggleTheme() })
        $this.OpenCommand = $this.NewCommand({ param($vm, $rowName) $vm.Open($rowName) })
        $this.EditCommand = $this.NewCommand({ param($vm, $rowName) $vm.ManagePacks($rowName) })
        $this.AppearanceCommand = $this.NewCommand({ param($vm, $rowName) $vm.SetAppearance($rowName) })
        $this.DuplicateCommand = $this.NewCommand({ param($vm, $rowName) $vm.Duplicate($rowName) })
        $this.ArchiveCommand = $this.NewCommand({ param($vm, $rowName) $vm.Archive($rowName) })
        $this.CompactCommand = $this.NewCommand({ param($vm, $rowName) $vm.Compact($rowName) })
        $this.RemoveCommand = $this.NewCommand({ param($vm, $rowName) $vm.Remove($rowName) })
        $this.RestoreCommand = $this.NewCommand({ param($vm, $rowName) $vm.Restore($rowName) })
        $this.DeleteArchiveCommand = $this.NewCommand({ param($vm, $rowName) $vm.DeleteArchive($rowName) })
    }

    # --- l'état ---------------------------------------------------------------

    # La relecture : la racine et les lignes.
    [void] Load() {
        try { $this._root = "$($this._fleet.GetRoot())" } catch { }
        try {
            $read = @($this._instance.GetAll())
            $this._rows = @($read | Where-Object { $null -ne $_ } | Sort-Object -Property Name -Stable |
                ForEach-Object { [InstanceRowViewModel]::new($_) })
            $this.OnPropertyChanged("Rows")
            $this.OnPropertyChanged("Root")
            if ($this._rows.Count -eq 0) {
                $this.SetStatus("No WSL Stack instances found.", $false)
                return
            }
            $this.SetStatus("$($this._rows.Count) row(s) loaded.", $false)
        } catch {
            $this.SetStatus("Error reading instances: $($_.Exception.Message)", $true)
        }
    }

    # La ligne d'état, deux voix : les nouvelles, et le rouge du refus.
    [void] SetStatus([string]$message, [bool]$alert) {
        $this._status = $message
        $this._alert = $alert
        $this.OnPropertyChanged("Status")
        $this.OnPropertyChanged("Alert")
    }

    # La bande et les mains liées, pour tout ce qui dure.
    [void] SetBusy([bool]$busy, [string]$message) {
        $this._busy = $busy
        $this.OnPropertyChanged("Busy")
        $this.OnPropertyChanged("Free")
        if ($message) { $this.SetStatus($message, $false) }
    }

    # Le filet de la vue, branché sur la ligne d'état.
    [void] Fail([string]$message) {
        $this.SetStatus($message, $true)
    }

    # Le monde en mémoire suit la racine écrite — après un migrate, les
    # services re-pointent avant que la liste ne se relise.
    [void] ReRoot() {
        try {
            $root = "$($this._fleet.GetRoot())"
            $this._fleet.ReRoot($root)
            $this._instance.ReRoot($root)
        } catch { }
    }

    # --- le thème -------------------------------------------------------------

    # L'autre version du thème : le choix est gardé, et la vue se rhabille
    # sur le cri (Appearance) — c'est elle qui sait porter une face.
    [void] ToggleTheme() {
        $variant = if ($this._variant -eq "Light") { "Dark" } else { "Light" }
        try { $this._wpf.SetVariant($variant) } catch {
            $this.SetStatus("Could not keep the $variant version: $($_.Exception.Message)", $true)
            return
        }
        $this._variant = $variant
        $this.OnPropertyChanged("Variant")
        $this.OnPropertyChanged("Appearance")
        $worn = if ($variant -eq "Light") { "light" } else { "dark" }
        $setName = if ($this._colourSet) { $this._colourSet } else { "default" }
        $this.SetStatus("The window wears '$setName', $worn version.", $false)
    }

    # --- les gestes des lignes ------------------------------------------------

    # Ouvrir un shell : sur place, le service s'en charge.
    [void] Open([string]$name) {
        try {
            $null = $this._instance.Open($name)
        } catch {
            $this.SetStatus("Open : $name - $($_.Exception.Message)", $true)
            return
        }
        $this.SetStatus("Open : $name", $false)
    }

    # Les packs : leur console est le déroulé — le déroulé EST le log.
    [void] ManagePacks([string]$name) {
        try { $packs = $this._instance.GetPacks($name) } catch {
            $this.SetStatus("ManagePacks : $name - $($_.Exception.Message)", $true)
            return
        }
        $dto = $this.ShowFace("ManagePacks", @($packs, $name))
        if (-not $dto) { return }
        $this.LaunchVisible("ManagePacks", "$($dto.InstanceName)", ($dto.ToAdd -join ','), ($dto.ToRemove -join ','))
        $this.SetStatus("Editing '$name's packs in a terminal.", $false)
    }

    # L'apparence d'une instance : le dialogue, puis l'application en direct.
    [void] SetAppearance([string]$name) {
        try {
            $appearance = $this._instance.GetAppearance($name)
            $fonts = @($this._instance.GetFonts())
            $schemes = @($this._instance.GetColorSchemes())
            $pairs = @($this._instance.GetIconPairs())
        } catch {
            $this.SetStatus("SetAppearance : $name - $($_.Exception.Message)", $true)
            return
        }
        $dto = $this.ShowFace("SetAppearance", @($name, $appearance, $fonts, $schemes, $pairs))
        if (-not $dto) {
            $this.SetStatus("SetAppearance : cancelled", $false)
            return
        }
        try {
            $null = $this._instance.SetAppearance($dto)
        } catch {
            $this.SetStatus("SetAppearance : $($dto.InstanceName) - $($_.Exception.Message)", $true)
            return
        }
        $this.Load()
        $this.SetStatus("SetAppearance : $($dto.InstanceName)", $false)
    }

    # --- les six longs : le dialogue, puis l'ouvrier caché --------------------

    [void] Archive([string]$name) {
        $rows = @($this._instance.GetAll())
        $dto = $this.ShowFace("Archive", @($name, $rows))
        if (-not $dto) { return }
        $this.StartLong("Archive", $name, "$($dto.Format)", "Archiving '$name' as '${name}_archive'...")
    }

    [void] Remove([string]$name) {
        $rows = @($this._instance.GetAll())
        $dto = $this.ShowFace("Remove", @($name, $rows))
        if (-not $dto) { return }
        $first = if ([bool]$dto.ArchiveFirst) { "True" } else { "False" }
        $this.StartLong("Remove", $name, $first, "Removing '$name'...")
    }

    [void] Compact([string]$name) {
        $rows = @($this._instance.GetAll())
        $dto = $this.ShowFace("Compact", @($name, $rows))
        if (-not $dto) { return }
        $first = if ([bool]$dto.ArchiveFirst) { "True" } else { "False" }
        $this.StartLong("Compact", $name, $first, "Compacting '$name'...")
    }

    [void] Restore([string]$name) {
        $rows = @($this._instance.GetAll())
        $dto = $this.ShowFace("Restore", @($rows, $name))
        if (-not $dto) { return }
        $this.StartLong("Restore", $name, "$($dto.InstanceName)", "Restoring '$name' as '$($dto.InstanceName)'...")
    }

    [void] Duplicate([string]$name) {
        $dto = $this.ShowFace("Duplicate", @($name))
        if (-not $dto) { return }
        $this.StartLong("Duplicate", $name, "$($dto.CopyName)", "Duplicating '$name' as '$($dto.CopyName)'...")
    }

    [void] DeleteArchive([string]$name) {
        $named = $this.ShowFace("DeleteArchive", @($name))
        if (-not $named) { return }
        $this.StartLong("DeleteArchive", "$named", "", "Deleting the archive '$named'...")
    }

    # Le lancement d'une chose longue : le journal vidé, l'ouvrier caché, la
    # ligne qui s'efface derrière sa bande. Le battement tourne déjà (le
    # minuteur de la vue toppe Tick) — rien à poser ici. La ligne est
    # assemblée à la main, chaque valeur citée : un tableau est joint
    # aveuglément, et un nom qui casse la ligne est refusé ici, avant.
    hidden [void] StartLong([string]$verb, [string]$name, [string]$arg1, [string]$message) {
        $workerPath = Join-Path $this._runners "$($verb)Runner.ps1"
        $log = Join-Path $env:TEMP "wsl-stack-gui-job.log"
        Remove-Item -LiteralPath $log -ErrorAction SilentlyContinue

        $this.SpinRow($name, $true)
        $this.SetBusy($true, $message)

        if (-not (Test-ProcessArguments @($verb, $name, $arg1, $this._assets, $this._root))) {
            $this.SpinRow($name, $false)
            $this.SetBusy($false, "")
            $this.SetStatus("The job was not launched: a value carries a double quote or a trailing backslash.", $true)
            return
        }

        try {
            $this.Worker = Start-Process pwsh -PassThru -WindowStyle Hidden -ArgumentList @(
                "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", "`"$workerPath`"",
                "`"$name`"", "`"$arg1`"", "`"`"", "`"$($this._assets)`"", "`"$($this._root)`"")
            $this.WorkerVerb = $verb
            $this.WorkerName = $name
            $this.Ticks = 0
        } catch {
            $this.SpinRow($name, $false)
            $this.SetBusy($false, "")
            $this.SetStatus("Could not start watching the job: $($_.Exception.Message)", $true)
        }
    }

    # Une console qu'on regarde : le déroulé EST le log. La fenêtre guette sa
    # sortie — la racine a pu changer (le migrate), l'instance naître (la
    # build).
    hidden [void] LaunchVisible([string]$verb, [string]$name, [string]$arg1, [string]$arg2) {
        $workerPath = Join-Path $this._runners "$($verb)Runner.ps1"
        if (-not (Test-ProcessArguments @($verb, $name, $arg1, $arg2, $this._assets, $this._root))) {
            $this.SetStatus("The job was not launched: a value carries a double quote or a trailing backslash.", $true)
            return
        }
        try {
            $this.Console = Start-Process pwsh -PassThru -ArgumentList @(
                "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$workerPath`"",
                "`"$name`"", "`"$arg1`"", "`"$arg2`"", "`"$($this._assets)`"", "`"$($this._root)`"")
        } catch {
            $this.SetBusy($false, "")
            $this.SetStatus("Could not open the console: $($_.Exception.Message)", $true)
        }
    }

    # Un tour de guet : l'ouvrier caché d'abord — vivant, il le dit (le compte
    # prouve que le minuteur bat) ; sorti, le journal dit la fin, et quoi qu'il
    # arrive la bande retombe, la liste se relit. Puis la console visible,
    # rendue : le monde en mémoire re-root, puis la liste.
    [void] Tick() {
        if ($null -ne $this.Worker) {
            if (-not $this.Worker.HasExited) {
                $this.Ticks++
                $this.SetStatus("The $($this.WorkerVerb.ToLower()) of '$($this.WorkerName)' - running - tick $($this.Ticks)", $false)
                return
            }

            $ending = ""
            $alert = $false
            $keepLog = $false
            $log = Join-Path $env:TEMP "wsl-stack-gui-job.log"
            try {
                $this.Ticks = 0
                $trail = @(Get-Content -LiteralPath $log -ErrorAction SilentlyContinue)
                $ok = @($trail | Where-Object { $_ -like "*RESULT OK *" } | Select-Object -Last 1)
                $bad = @($trail | Where-Object { $_ -like "*RESULT FAIL *" } | Select-Object -Last 1)
                if ($bad.Count -gt 0) {
                    $ending = "Failed to $($this.WorkerVerb.ToLower()) '$($this.WorkerName)': " + ($bad[0] -replace "^.*?RESULT FAIL ", "")
                    $alert = $true
                } elseif ($ok.Count -gt 0) {
                    $ending = ($ok[0] -replace "^.*?RESULT OK ", "")
                } else {
                    $ending = "The $($this.WorkerVerb.ToLower()) of '$($this.WorkerName)' ended (exit $($this.Worker.ExitCode)) with no result in the trail ($log)."
                    $alert = $true
                    $keepLog = $true
                }
            } catch {
                $ending = "The watcher failed: $($_.Exception.Message)"
                $alert = $true
            } finally {
                $this.SpinRow($this.WorkerName, $false)
                $this.Worker = $null
                $this.SetBusy($false, "")
                $this.Load()
                if ($ending) { $this.SetStatus($ending, $alert) }
                if (-not $keepLog) { Remove-Item -LiteralPath $log -ErrorAction SilentlyContinue }
            }
            return
        }

        if ($null -ne $this.Console) {
            if (-not $this.Console.HasExited) { return }
            $this.Console = $null
            $this.SetBusy($false, "")
            $this.ReRoot()
            $this.Load()
            $this.SetStatus("Done - the fleet was reread.", $false)
        }
    }

    # La ligne dit qu'elle travaille : ses icônes cèdent la place au petit
    # ruban. Cosmétique, et gardé — la chose ne doit jamais en dépendre.
    hidden [void] SpinRow([string]$name, [bool]$on) {
        try {
            foreach ($row in $this._rows) {
                if ("$($row.Name)" -eq "$name") { $row.Spin($on) }
            }
        } catch { }
    }

    # --- l'entête : la naissance et les Réglages ------------------------------

    # La naissance : le dialogue (ses listes, ses portes liées au service),
    # puis le Dto en clair dans un fichier — le dessin est trop pour une
    # ligne de commande — et l'ouvrier visible, guetté.
    [void] Add() {
        try {
            $sources = $this._instance.GetBuildSources()
            $images = @($this._instance.GetAllSavedImages())
            $packs = @($this._instance.GetBuildPacks())
            $checkRegistry = $this._instance.IsRegistryImageValid
            $doors = [PSCustomObject]@{
                Taken  = @($this._instance.GetAll() | Where-Object { -not $_.IsArchive } | ForEach-Object { $_.Name })
                Upload = $this._instance.UploadRecipe
                Delete = $this._instance.DeleteRecipe
                Export = $this._instance.ExportRecipe
            }
        } catch {
            $this.SetStatus("Build : $($_.Exception.Message)", $true)
            return
        }

        $dto = $this.ShowFace("Build", @($sources, $images, $packs, $checkRegistry, $doors))
        if (-not $dto) { return }

        $json = Join-Path $env:TEMP "wsl-stack-build.json"
        $payload = [PSCustomObject]@{
            Name           = "$($dto.Name)"
            User           = "$($dto.User)"
            BuildType      = "$($dto.BuildType)"
            BuildPath      = "$($dto.BuildPath)"
            Context        = "$($dto.Context)"
            Onboarding     = "$($dto.Onboarding)"
            Packs          = @($dto.Packs)
            KeepImage      = [bool]$dto.KeepImage
            RegisterDocker = [bool]$dto.RegisterDocker
        }
        [System.IO.File]::WriteAllText($json, ($payload | ConvertTo-Json -Depth 4), [System.Text.UTF8Encoding]::new($false))
        $this.SetBusy($true, "Creating '$($dto.Name)' in terminal.")
        $this.LaunchVisible("Build", "$($dto.Name)", $json, "")
    }

    # Les Réglages : le dialogue rend ce qui fut choisi. Le look s'applique au
    # service, et la vue se rhabille sur le cri (Appearance). Un dossier
    # d'arrivée confirmé : l'ouvrier visible (MigrateRunner) et sa console.
    [void] Settings() {
        try {
            $theme = $this._wpf.GetTheme()
            $themes = @($this._wpf.GetColorThemes())
            $fonts = @($this._wpf.GetFontChoices())
            $packs = @($this._catalogue.GetAllPacks())
            $root = $this._fleet.GetRoot()
            $doors = [PSCustomObject]@{
                UploadFont    = $this._wpf.UploadFont
                UploadTheme   = $this._wpf.UploadTheme
                DeleteTheme   = $this._wpf.DeleteTheme
                ExportTheme   = $this._wpf.ExportTheme
                OpenTheme     = $this._wpf.OpenTheme
                PackOpen      = $this._catalogue.OpenPackFolder
                PackDuplicate = $this._catalogue.CreatePack
                PackDelete    = $this._catalogue.DeletePack
                PackRefresh   = $this._catalogue.GetAllPacks
            }
        } catch {
            $this.SetStatus("Settings : $($_.Exception.Message)", $true)
            return
        }

        $picked = $this.ShowFace("Settings", @($theme, $themes, $fonts, $packs, $root, $this._assets, $doors))
        if (-not $picked) { return }

        if ($picked.PSObject.Properties['Status']) {
            $this.SetStatus("$($picked.Message)", ("$($picked.Status)" -eq "Nok"))
            return
        }

        try {
            $this._wpf.SetFontFamily($picked.FontFamily)
            $this._wpf.SetFontSize($picked.FontSize)
            $this._wpf.SetColorTheme($picked.ColorTheme)
            $this._wpf.SetVariant($picked.Variant)
        } catch {
            $this.SetStatus("Settings : $($picked.FontFamily)/$($picked.ColorTheme) - $($_.Exception.Message)", $true)
            return
        }
        if ($picked.ColorTheme) { $this._colourSet = "$($picked.ColorTheme)" }
        $this._variant = "$($picked.Variant)"
        $this.OnPropertyChanged("ColourSet")
        $this.OnPropertyChanged("Variant")
        $this.OnPropertyChanged("Appearance")
        $this.Load()

        if ($picked.NewRoot) {
            $this.SetBusy($true, "Moving the fleet to '$($picked.NewRoot)'...")
            $this.LaunchVisible("Migrate", "$($picked.NewRoot)", "", "")
            return
        }

        $setName = if ($this._colourSet) { $this._colourSet } else { "default" }
        $this.SetStatus("Window face: '$($picked.FontFamily)' at $($picked.FontSize) pt, theme '$setName'. Popups follow on their next open.", $false)
    }

    # --- les dialogues --------------------------------------------------------

    # La vue d'un geste, par son nom : le guet d'assemblée — le ViewModel ne
    # connaît pas le WPF, la classe se trouve à l'exécution (mesuré : c'est
    # la même porte que la résolution des vues d'avant). Ask, ses arguments,
    # et son retour — rien quand rien n'a été rendu.
    hidden [object] ShowFace([string]$gesture, [object[]]$arguments) {
        # Le fichier d'abord : le guet ne trouve que ce qui est chargé — le
        # module de la vue s'importe ici, où qu'elle vive sous Views\WPF.
        try {
            $file = @(Get-ChildItem -Path $this._views -Recurse -Filter "$gesture.xaml.ps1" -File -ErrorAction SilentlyContinue)[0]
            if ($file) { $null = Import-Module $file.FullName -ErrorAction SilentlyContinue }
        } catch { }

        $wanted = "Wpf${gesture}View"
        $face = $null
        foreach ($assembly in [AppDomain]::CurrentDomain.GetAssemblies()) {
            try { $face = @($assembly.GetTypes() | Where-Object { $_.Name -eq $wanted })[0] } catch { }
            if ($face) { break }
        }
        if (-not $face) {
            $this.SetStatus("$gesture : the dialog '$wanted' was not found.", $true)
            return $null
        }
        $view = $face::new()
        $invoked = @($view.Ask.Invoke(@($arguments)))
        if ($invoked.Count -eq 0) { return $null }
        return $invoked[0]
    }
}
