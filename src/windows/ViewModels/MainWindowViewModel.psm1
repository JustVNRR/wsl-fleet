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
    [string]$Name = ""
    [string]$Size = ""
    [bool]$IsArchive = $false
    [bool]$IsBusy = $false
    # The Docker Desktop state, read with the index - the docker gesture
    # decides its direction on it.
    [string]$Docker = ""

    InstanceRowViewModel([object]$row) {
        $this.Name = "$($row.Name)"
        $this.Size = Format-Size ([double]$row.Size)
        $this.IsArchive = [bool]$row.IsArchive
        $this.Docker = "$($row.Docker)"
    }

    [void] Spin([bool]$on) {
        $this.Set("IsBusy", $on)
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

    # L'état bindable : de VRAIES propriétés — WPF ne lit que celles-là.
    [object[]]$Rows = @()
    [string]$Root = ""
    [string]$Status = "Ready."
    [bool]$Alert = $false
    [bool]$Busy = $false
    [bool]$Free = $true
    [string]$ColourSet = ""
    [string]$Variant = "Dark"

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
    [System.Windows.Input.ICommand]$DockerCommand
    [System.Windows.Input.ICommand]$RemoveCommand
    [System.Windows.Input.ICommand]$RestoreCommand
    [System.Windows.Input.ICommand]$DeleteArchiveCommand

    MainWindowViewModel([object]$instanceService, [object]$fleetService, [object]$wpfService,
                        [object]$packCatalog, [string]$assetsDir, [string]$runnersDir) {
        $this._instance = $instanceService
        $this._fleet = $fleetService
        $this._wpf = $wpfService
        $this._catalogue = $packCatalog
        $this._assets = $assetsDir
        $this._runners = $runnersDir

        try {
            $look = $this._wpf.GetTheme()
            $this.ColourSet = "$($look.ColorTheme)"
            $this.Variant = if ("$($look.Variant)") { "$($look.Variant)" } else { "Dark" }
        } catch { }

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
        $this.DockerCommand = $this.NewCommand({ param($vm, $rowName) $vm.DockerDesktop($rowName) })
        $this.RemoveCommand = $this.NewCommand({ param($vm, $rowName) $vm.Remove($rowName) })
        $this.RestoreCommand = $this.NewCommand({ param($vm, $rowName) $vm.Restore($rowName) })
        $this.DeleteArchiveCommand = $this.NewCommand({ param($vm, $rowName) $vm.DeleteArchive($rowName) })
    }

    # --- l'état ---------------------------------------------------------------

    # La relecture : la racine et les lignes.
    [void] Load() {
        try { $this.Root = "$($this._fleet.GetRoot())" } catch { }
        try {
            $read = @($this._instance.GetAll())
            $this.Rows = @($read | Where-Object { $null -ne $_ } | Sort-Object -Property Name -Stable |
                ForEach-Object { [InstanceRowViewModel]::new($_) })
            $this.OnPropertyChanged("Rows")
            $this.OnPropertyChanged("Root")
            if ($this.Rows.Count -eq 0) {
                $this.SetStatus("No WSL Stack instances found.", $false)
                return
            }
            $this.SetStatus("$($this.Rows.Count) row(s) loaded.", $false)
        } catch {
            $this.SetStatus("Error reading instances: $($_.Exception.Message)", $true)
        }
    }

    # La ligne d'état, deux voix : les nouvelles, et le rouge du refus.
    [void] SetStatus([string]$message, [bool]$alert) {
        $this.Set("Status", $message)
        $this.Set("Alert", $alert)
    }

    # La bande et les mains liées, pour tout ce qui dure.
    [void] SetBusy([bool]$busy, [string]$message) {
        $this.Set("Busy", $busy)
        $this.Set("Free", (-not $busy))
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
            $target = "$($this._fleet.GetRoot())"
            $this._fleet.ReRoot($target)
            $this._instance.ReRoot($target)
        } catch { }
    }

    # --- le thème -------------------------------------------------------------

    # L'autre version du thème : le choix est gardé, et la vue se rhabille
    # sur le cri (Appearance) — c'est elle qui sait porter une face.
    [void] ToggleTheme() {
        # $other : une locale ne peut pas porter le nom d'une propriété
        # réelle (mesuré au parse).
        $other = if ($this.Variant -eq "Light") { "Dark" } else { "Light" }
        try { $this._wpf.SetVariant($other) } catch {
            $this.SetStatus("Could not keep the $other version: $($_.Exception.Message)", $true)
            return
        }
        $this.Set("Variant", $other)
        $this.OnPropertyChanged("Appearance")
        $worn = if ($other -eq "Light") { "light" } else { "dark" }
        $setName = if ($this.ColourSet) { $this.ColourSet } else { "default" }
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
        $all = @($this._instance.GetAll())
        $dto = $this.ShowFace("Archive", @($name, $all))
        if (-not $dto) { return }
        $this.StartLong("Archive", $name, "$($dto.Format)", "Archiving '$name' as '${name}_archive'...")
    }

    [void] Remove([string]$name) {
        $dto = $this.ShowFace("Remove", @($name))
        if (-not $dto) { return }
        $first = if ([bool]$dto.ArchiveFirst) { "True" } else { "False" }
        $this.StartLong("Remove", $name, $first, "Removing '$name'...")
    }

    [void] Compact([string]$name) {
        $dto = $this.ShowFace("Compact", @($name))
        if (-not $dto) { return }
        $first = if ([bool]$dto.ArchiveFirst) { "True" } else { "False" }
        $this.StartLong("Compact", $name, $first, "Compacting '$name'...")
    }

    # Docker Desktop: the row's state decides the direction, the face carries
    # the sentence and the restart box, the runner the write and the restart.
    # A state that cannot be read stops here, said.
    [void] DockerDesktop([string]$name) {
        $state = ""
        foreach ($row in $this.Rows) {
            if ("$($row.Name)" -ceq "$name") { $state = "$($row.Docker)"; break }
        }
        if ($state -ne "yes" -and $state -ne "no") {
            $this.SetStatus("DockerDesktop : $name - its Docker Desktop state cannot be read.", $true)
            return
        }

        $answered = $this.ShowFace("DockerRegister", @($name, $state))
        if (-not $answered) { return }

        $action = if ($state -eq "yes") { "unregister" } else { "register" }
        $restart = if ($answered.Restart) { "True" } else { "False" }
        $message = if ($action -eq "register") { "Registering '$name' with Docker Desktop..." } else { "Taking '$name' out of Docker Desktop..." }
        $this.StartLong("DockerRegister", $name, $action, $message, $restart)
    }

    [void] Restore([string]$name) {
        $dto = $this.ShowFace("Restore", @($name))
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
    hidden [void] StartLong([string]$verb, [string]$name, [string]$arg1, [string]$message, [string]$arg2 = "") {
        $workerPath = Join-Path $this._runners "$($verb)Runner.ps1"
        $log = Join-Path $env:TEMP "wsl-stack-gui-job.log"
        Remove-Item -LiteralPath $log -ErrorAction SilentlyContinue

        $this.SpinRow($name, $true)
        $this.SetBusy($true, $message)

        if (-not (Test-ProcessArguments @($verb, $name, $arg1, $arg2, $this._assets, $this.Root))) {
            $this.SpinRow($name, $false)
            $this.SetBusy($false, "")
            $this.SetStatus("The job was not launched: a value carries a double quote or a trailing backslash.", $true)
            return
        }

        try {
            $this.Worker = Start-Process pwsh -PassThru -WindowStyle Hidden -ArgumentList @(
                "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", "`"$workerPath`"",
                "`"$name`"", "`"$arg1`"", "`"$arg2`"", "`"$($this._assets)`"", "`"$($this.Root)`"")
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
        if (-not (Test-ProcessArguments @($verb, $name, $arg1, $arg2, $this._assets, $this.Root))) {
            $this.SetStatus("The job was not launched: a value carries a double quote or a trailing backslash.", $true)
            return
        }
        try {
            $this.Console = Start-Process pwsh -PassThru -ArgumentList @(
                "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$workerPath`"",
                "`"$name`"", "`"$arg1`"", "`"$arg2`"", "`"$($this._assets)`"", "`"$($this.Root)`"")
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
            # $alarm : une locale ne peut pas porter le nom d'une propriété
            # réelle (mesuré au parse).
            $alarm = $false
            $keepLog = $false
            $log = Join-Path $env:TEMP "wsl-stack-gui-job.log"
            try {
                $this.Ticks = 0
                $trail = @(Get-Content -LiteralPath $log -ErrorAction SilentlyContinue)
                $ok = @($trail | Where-Object { $_ -like "*RESULT OK *" } | Select-Object -Last 1)
                $bad = @($trail | Where-Object { $_ -like "*RESULT FAIL *" } | Select-Object -Last 1)
                if ($bad.Count -gt 0) {
                    $ending = "Failed to $($this.WorkerVerb.ToLower()) '$($this.WorkerName)': " + ($bad[0] -replace "^.*?RESULT FAIL ", "")
                    $alarm = $true
                } elseif ($ok.Count -gt 0) {
                    $ending = ($ok[0] -replace "^.*?RESULT OK ", "")
                } else {
                    $ending = "The $($this.WorkerVerb.ToLower()) of '$($this.WorkerName)' ended (exit $($this.Worker.ExitCode)) with no result in the trail ($log)."
                    $alarm = $true
                    $keepLog = $true
                }
            } catch {
                $ending = "The watcher failed: $($_.Exception.Message)"
                $alarm = $true
            } finally {
                $this.SpinRow($this.WorkerName, $false)
                $this.Worker = $null
                $this.SetBusy($false, "")
                $this.Load()
                if ($ending) { $this.SetStatus($ending, $alarm) }
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
            $this.SetStatus("Done - the fleet was refreshed.", $false)
        }
    }

    # La ligne dit qu'elle travaille : ses icônes cèdent la place au petit
    # ruban. Cosmétique, et gardé — la chose ne doit jamais en dépendre.
    hidden [void] SpinRow([string]$name, [bool]$on) {
        try {
            foreach ($row in $this.Rows) {
                if ("$($row.Name)" -eq "$name") { $row.Spin($on) }
            }
        } catch { }
    }

    # --- l'entête : la naissance et les Réglages ------------------------------

    # La naissance : le dialogue (ses listes, ses portes liées au service),
    # puis le Dto en clair dans un fichier — le dessin est trop pour une
    # ligne de commande — et l'ouvrier visible, guetté.
    [void] Add() {
        $dto = $this.ShowFace("Build", @($this._instance))
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

    # Les Réglages : le dialogue (son ViewModel, les services en main) rend
    # ce qui fut choisi. Le look s'applique au service, et la vue se rhabille
    # sur le cri (Appearance). Un dossier d'arrivée confirmé : l'ouvrier
    # visible (MigrateRunner) et sa console.
    [void] Settings() {
        $picked = $this.ShowFace("Settings", @($this._wpf, $this._catalogue, $this._fleet, $this._assets))
        if (-not $picked) { return }

        try {
            $this._wpf.SetFontFamily($picked.FontFamily)
            $this._wpf.SetFontSize($picked.FontSize)
            $this._wpf.SetColorTheme($picked.ColorTheme)
            $this._wpf.SetVariant($picked.Variant)
        } catch {
            $this.SetStatus("Settings : $($picked.FontFamily)/$($picked.ColorTheme) - $($_.Exception.Message)", $true)
            return
        }
        if ($picked.ColorTheme) { $this.ColourSet = "$($picked.ColorTheme)" }
        $this.Variant = "$($picked.Variant)"
        $this.OnPropertyChanged("ColourSet")
        $this.OnPropertyChanged("Variant")
        $this.OnPropertyChanged("Appearance")
        $this.Load()

        if ($picked.NewRoot) {
            $this.SetBusy($true, "Moving the fleet to '$($picked.NewRoot)'...")
            $this.LaunchVisible("Migrate", "$($picked.NewRoot)", "", "")
            return
        }

        $setName = if ($this.ColourSet) { $this.ColourSet } else { "default" }
        $this.SetStatus("Window face: '$($picked.FontFamily)' at $($picked.FontSize) pt, theme '$setName'. Popups follow on their next open.", $false)
    }

    # --- les dialogues --------------------------------------------------------

    # La vue d'un geste, par son nom — la porte d'ouverture, posée par
    # l'entrée : le ViewModel ne connaît ni le nom des vues ni leur dossier.
    hidden [object] ShowFace([string]$gesture, [object[]]$arguments) {
        return $this.OpenBox($gesture, $arguments)
    }
}
