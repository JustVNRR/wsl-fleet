using module .\BaseViewModel.psm1
using module ..\Tools\Helpers.psm1
using module ..\Services\LoggerService.psm1
using module ..\Dtos\InstanceDto.psm1

class InstanceRowViewModel : BaseViewModel {

    [string]$Name = ""
    [string]$Size = ""
    [bool]$IsArchive = $false
    [bool]$IsBusy = $false
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

class MainWindowViewModel : BaseViewModel {

    hidden [object]$_instance
    hidden [object]$_fleet
    hidden [object]$_wpf
    hidden [object]$_catalogue
    hidden [string]$_assets = ""
    hidden [string]$_runners = ""
    hidden [object]$_log = $null
    hidden [bool]$_popping = $false
    [object[]]$Rows = @()
    [string]$Root = ""
    [bool]$Busy = $false
    [bool]$Free = $true
    [string]$ColourSet = ""
    [string]$Variant = "Dark"
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
    [System.Windows.Input.ICommand]$RestartCommand
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
                        [object]$packCatalog, [string]$assetsDir, [string]$runnersDir, [object]$logger) {
        $this._instance = $instanceService
        $this._fleet = $fleetService
        $this._wpf = $wpfService
        $this._catalogue = $packCatalog
        $this._assets = $assetsDir
        $this._runners = $runnersDir
        $this._log = $logger

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
        $this.RestartCommand = $this.NewCommand({ param($vm, $rowName) $vm.Restart($rowName) })
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

    [void] Load() {
        try { $this.Root = "$($this._fleet.GetRoot())" } catch { }
        try {
            $read = @($this._instance.GetAll())
            $this.Rows = @($read | Where-Object { $null -ne $_ } | Sort-Object -Property Name -Stable |
                ForEach-Object { [InstanceRowViewModel]::new($_) })
            $this.OnPropertyChanged("Rows")
            $this.OnPropertyChanged("Root")
            if ($this.Rows.Count -eq 0) {
                $this.SetStatus("No Wsl Fleet instances found.", $false)
                return
            }
            $this.SetStatus("$($this.Rows.Count) row(s) loaded.", $false)
        } catch {
            $this.SetStatus("Error reading instances: $($_.Exception.Message)", $true)
        }
    }

    [void] SetStatus([string]$message, [bool]$alert) {
        if (-not $this._log) { return }
        $entry = [LogEntryDto]::new()
        $entry.When = Get-Date
        $entry.Level = if ($alert) { "ERROR" } else { "INFO" }
        $entry.Message = "$message"
        $this._log.Write($entry)
        if ($alert -and -not $this._popping) {
            $this._popping = $true
            try { $null = $this.ShowFace("Error", @($entry)) } finally { $this._popping = $false }
        }
    }

    [void] SetBusy([bool]$busy, [string]$message) {
        $this.Set("Busy", $busy)
        $this.Set("Free", (-not $busy))
        if ($message) { $this.SetStatus($message, $false) }
    }

    [void] Fail([string]$message) {
        $this.SetStatus($message, $true)
    }

    [void] ReRoot() {
        try {
            $target = "$($this._fleet.GetRoot())"
            $this._fleet.ReRoot($target)
            $this._instance.ReRoot($target)
        } catch { }
    }

    [void] ToggleTheme() {
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

    [void] Open([string]$name) {
        try {
            $null = $this._instance.Open($name)
        } catch {
            $this.SetStatus("Open : $name - $($_.Exception.Message)", $true)
            return
        }
        $this.SetStatus("Open : $name", $false)
    }

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

    [void] Restart([string]$name) {
        $this.StartLong("Restart", $name, "", "Restarting '$name'...")
    }

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

    hidden [void] StartLong([string]$verb, [string]$name, [string]$arg1, [string]$message) {
        $this.StartLong($verb, $name, $arg1, $message, "")
    }

    hidden [void] StartLong([string]$verb, [string]$name, [string]$arg1, [string]$message, [string]$arg2) {
        $workerPath = Join-Path $this._runners "$($verb)Runner.ps1"
        $log = Join-Path $env:TEMP "wsl-fleet-gui-job.log"
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

    [void] Tick() {
        if ($null -ne $this.Worker) {
            if (-not $this.Worker.HasExited) {
                $this.Ticks++
                return
            }

            $ending = ""
            $alarm = $false
            $keepLog = $false
            $log = Join-Path $env:TEMP "wsl-fleet-gui-job.log"
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

    hidden [void] SpinRow([string]$name, [bool]$on) {
        try {
            foreach ($row in $this.Rows) {
                if ("$($row.Name)" -eq "$name") { $row.Spin($on) }
            }
        } catch { }
    }

    [void] Add() {
        $dto = $this.ShowFace("Build", @($this._instance))
        if (-not $dto) { return }

        $json = Join-Path $env:TEMP "wsl-fleet-build.json"
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

    hidden [object] ShowFace([string]$gesture, [object[]]$arguments) {
        return $this.OpenBox($gesture, $arguments)
    }
}
