# ==============================================================================
# LA FENÊTRE PRINCIPALE — LA VUE WPF
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewWpf.psm1
using module ..\..\..\Tools\Helpers.psm1

# Le home du gui — la fenêtre de l'appli : l'entête (racine, Add, Refresh,
# Réglages, soleil/lune, fermer), le tableau, la bande, la ligne d'état. Elle
# vit tant qu'on ne la ferme pas : Ask pousse un cadre de dispatcher, pas un
# ShowDialog — elle est la racine, pas une boîte. Toutes ses portes lui
# arrivent liées (le contrôleur et l'entrée les ont bâties) : les gestes des
# lignes rendent un ActionResult — la ligne d'état est leur trail —, et les
# LONGS rendent leur porte (le Dto, ou rien) : c'est elle qui mène le reste.
#
# Les longs ne courent jamais sous elle : un appel à wsl.exe y prendrait des
# minutes, le fil bloqué. La porte s'ouvre, la ligne s'efface derrière sa
# bande, et l'ouvrier part — un processus à part (Runners\<Geste>Runner.ps1,
# un par geste), caché, qui écrit son journal ; la sentinelle guette (400 ms)
# et la fin revient par le journal : la bande retombe, la liste se relit, la
# ligne d'état parle. Les deux visibles — les packs, la naissance —
# s'ouvrent dans une console qu'on regarde : le déroulé EST le log. Le voyage
# d'une racine déplacée, lui, se court sur place : la fenêtre s'écarte
# pendant qu'il passe, et revient.
class WpfMainView : BaseViewWpf {
    hidden [object]$Doors = $null
    hidden [object]$Look = $null
    hidden [string]$ColourSet = ""
    hidden [string]$Root = ""
    hidden [object]$Child = $null
    hidden [object]$Poller = $null
    hidden [int]$Ticks = 0
    hidden [string]$JobVerb = ""
    hidden [string]$JobName = ""
    hidden [object]$ConsoleChild = $null
    hidden [object]$ConsoleWatch = $null

    [string] Ask([object[]]$rows, [string]$rootPath, [object]$theme, [object]$doors) {
        $self = $this
        $this.Doors = $doors
        $this.Look = $theme
        $this.ColourSet = if ($theme) { "$($theme.ColorTheme)" } else { "" }
        # Pas de locale qui porte le nom d'une propriété de la classe ($Root,
        # ici) : l'affectation nue est refusée au parse (mesuré — MissingThis).
        $this.Root = "$rootPath"

        $this.Title = "WSL Stack Manager"
        $this.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
        $this.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $this.MinHeight = 240
        $this.Load((Join-Path $PSScriptRoot "Main.xaml"))
        $this.WearDefault()
        $this.Dress($null, 15)
        # Le socle la connaît : c'est derrière ELLE que les boîtes s'ouvrent —
        # elle s'efface le temps qu'elles vivent, et revient.
        [BaseViewWpf]::Main = $this

        $this.Find("TxtRoot").Text = "Root: $rootPath"

        # L'entête.
        $this.Find("BtnQuit").Add_Click({ $self.Close() })
        $this.Find("BtnRefresh").Add_Click({ $self.Reload() })
        $this.Find("BtnAdd").Add_Click({ $self.Add() })
        $this.Find("BtnSettings").Add_Click({ $self.Settings() })

        # Le soleil et la lune : l'autre version du thème, en direct sous la
        # fenêtre — le dictionnaire est REMPLACÉ, et le choix est gardé.
        $this.Find("BtnTheme").Add_Click({
            $variant = if ("$($self.Look.Variant)" -eq "Light") { "Dark" } else { "Light" }
            $door = $self.Door("SetVariant")
            if ($door) {
                try { $null = $door.Invoke(@($variant)) }
                catch { $self.SetStatus("Could not keep the $variant version: $($_.Exception.Message)", $true); return }
            }
            if ($self.Look) { $self.Look.Variant = $variant }
            $self.WearTheme([BaseViewWpf]::Assets, $self.ColourSet, $variant)
            $self.Dress($null, 15)
            $self.UpdateThemeButton()
            $worn = if ($variant -eq "Light") { "light" } else { "dark" }
            $setName = if ($self.ColourSet) { $self.ColourSet } else { "default" }
            $self.SetStatus("The window wears '$setName', $worn version.", $false)
        })

        # Les icônes des lignes remontent leur clic à la liste : l'OriginalSource
        # est le bouton, son DataContext la ligne — son nom dit le geste.
        $verbs = @{
            "BtnRowRestore"       = "Restore"
            "BtnRowDeleteArchive" = "DeleteArchive"
            "BtnRowOpen"          = "Open"
            "BtnRowEdit"          = "ManagePacks"
            "BtnRowAppearance"    = "SetAppearance"
            "BtnRowDuplicate"     = "Duplicate"
            "BtnRowArchive"       = "Archive"
            "BtnRowCompact"       = "Compact"
            "BtnRowRemove"        = "Remove"
        }
        $rowAction = [System.Windows.RoutedEventHandler]{
            param($source, $e)
            $button = $e.OriginalSource
            $row = $button.DataContext
            if ($null -eq $row) { return }
            $verb = $verbs["$($button.Name)"]
            if (-not $verb) { return }
            $self.Dispatch($verb, "$($row.Name)", $button)
        }
        $this.Find("LstInstances").AddHandler([System.Windows.Controls.Button]::ClickEvent, $rowAction)

        # Échap ferme — sauf quand la main tape dans un champ : la ligne d'état
        # est la seule boîte ici, et une touche dedans est à elle.
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
        # dite sur la ligne d'état, la fenêtre vit. Décroché à la sortie : un
        # poignée laissée sur le dispatcher épingle le lancement tout entier.
        $safetyNet = [System.Windows.Threading.DispatcherUnhandledExceptionEventHandler]{
            param($source, $e)
            $e.Handled = $true
            $where = ""
            if ($e.Exception.ErrorRecord -and $e.Exception.ErrorRecord.ScriptStackTrace) {
                $where = " @ " + (($e.Exception.ErrorRecord.ScriptStackTrace -split "`n")[0] -replace '^\s+', '')
            }
            try { $self.SetStatus("A drawing failed: $($e.Exception.Message)$where", $true) } catch { }
        }
        $this.Dispatcher.Add_UnhandledException($safetyNet)

        # La racine se montre — le cadre de l'appli, pas une boîte : fermer la
        # fenêtre le fait sortir.
        $frame = [System.Windows.Threading.DispatcherFrame]::new()
        $this.Add_Closed({ $frame.Continue = $false })

        $this.UpdateThemeButton()
        $this.Fill($rows)

        try {
            $this.Show()
            # Montrée : elle a un écran, et le plafond suit celui-là.
            $this.FitCeiling()
            # Le lancement a laissé la console devant — la fenêtre était faite
            # par son processus : elle demande le premier plan. Activate
            # d'abord, puis le va-et-vient topmost, que Windows écoute.
            $null = $this.Activate()
            $this.Topmost = $true
            $this.Topmost = $false
            # Échap a besoin d'un foyer pour voyager — la liste le prend.
            $null = $this.Find("LstInstances").Focus()
            [System.Windows.Threading.Dispatcher]::PushFrame($frame)
        } finally {
            $this.Dispatcher.Remove_UnhandledException($safetyNet)
            # Rien de ce lancement ne reste accroché : un minuteur laissé en
            # marche tiendrait le lancement jusqu'à la fin de l'enfant.
            if ($this.Poller) { $this.Poller.Stop() }
            if ($this.ConsoleWatch) { $this.ConsoleWatch.Stop() }
            [BaseViewWpf]::Main = $null
            [BaseViewWpf]::Depth = 0
        }
        return "closed"
    }

    # Un clic de ligne, par famille : les courts sur place, les six longs à
    # l'ouvrier, les packs dans leur console.
    hidden [void] Dispatch([string]$verb, [string]$name, [object]$button) {
        if ($verb -in @("Remove", "Compact", "Archive", "Restore", "Duplicate", "DeleteArchive")) {
            $this.Long($verb, $name, $button)
            return
        }
        if ($verb -eq "ManagePacks") {
            $this.Packs($name)
            return
        }
        $this.Run($verb, $name)
    }

    # Un court geste, par sa porte : le résultat va sur la ligne d'état, et la
    # liste se relit quand la chose est faite — l'abandon ne relit rien.
    hidden [void] Run([string]$verb, [string]$target) {
        $door = $this.Door($verb)
        if (-not $door) { return }
        $invoked = if ($target) { @($door.Invoke(@($target))) } else { @($door.Invoke(@())) }
        if ($invoked.Count -eq 0) { return }
        $result = $invoked[0]
        if (-not $result) { return }
        $ok = ("$($result.Status)" -eq "Ok") -and ("$($result.Message)" -notlike "*: cancelled")
        if ($ok) { $this.Reload() }
        $this.SetStatus("$($result.Message)", ("$($result.Status)" -eq "Nok"))
    }

    # Un long geste : la porte rend son Dto (ou rien, l'abandon) — puis la
    # ligne s'efface derrière sa bande, et l'ouvrier part.
    hidden [void] Long([string]$verb, [string]$name, [object]$button) {
        $door = $this.Door($verb)
        if (-not $door) { return }
        $invoked = @($door.Invoke(@($name)))
        if ($invoked.Count -eq 0) { return }
        $dto = $invoked[0]
        if (-not $dto) { return }

        $arg1 = ""
        if ($verb -in @("Remove", "Compact")) { $arg1 = if ([bool]$dto.ArchiveFirst) { "True" } else { "False" } }
        elseif ($verb -eq "Archive") { $arg1 = "$($dto.Format)" }
        elseif ($verb -eq "Restore") { $arg1 = "$($dto.InstanceName)" }
        elseif ($verb -eq "Duplicate") { $arg1 = "$($dto.CopyName)" }

        $message = switch ($verb) {
            "Remove" { "Removing '$name'..." }
            "Compact" { "Compacting '$name'..." }
            "Archive" { "Archiving '$name' as '${name}_archive'..." }
            "Restore" { "Restoring '$name' as '$arg1'..." }
            "Duplicate" { "Duplicating '$name' as '$arg1'..." }
            "DeleteArchive" { "Deleting the archive '$name'..." }
        }

        $this.MarkRow($button)
        $this.SetBusy($true, $message)
        $this.LaunchJob($verb, $name, $arg1)
    }

    # Les packs : leur console est le déroulé — le déroulé EST le log. Pas de
    # bande, pas de guet : la fenêtre reste à la main, la console est la
    # progression.
    hidden [void] Packs([string]$name) {
        $door = $this.Door("ManagePacks")
        if (-not $door) { return }
        $invoked = @($door.Invoke(@($name)))
        if ($invoked.Count -eq 0) { return }
        $dto = $invoked[0]
        if (-not $dto) { return }
        $this.LaunchVisible("ManagePacks", "$($dto.InstanceName)", ($dto.ToAdd -join ','), ($dto.ToRemove -join ','))
        $this.SetStatus("Editing '$name's packs in a terminal.", $false)
    }

    # La naissance : la porte rend le Dto, le Dto voyage en clair dans un
    # fichier (le dessin, les listes — trop pour une ligne de commande),
    # l'ouvrier le relit — et le docker build s'ouvre dans une console qu'on
    # regarde, pendant que la bande tourne ici.
    hidden [void] Add() {
        $door = $this.Door("Build")
        if (-not $door) { return }
        # La porte peut n'avoir RIEN rendu (le formulaire abandonné) : rien à
        # indexer — on embrasse, on regarde, on prend ensuite (vécu : le
        # Cancel de la naissance jurait ici).
        $invoked = @($door.Invoke(@()))
        if ($invoked.Count -eq 0) { return }
        $dto = $invoked[0]
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
        $this.LaunchBuild("$($dto.Name)", $json)
    }

    # Le Réglages : la porte rend ce qui fut choisi (ou rien). La face se
    # remet ici même — le dictionnaire est remplacé, rien d'autre ne bouge.
    # Un dossier d'arrivée confirmé : la fenêtre envoie l'ouvrier
    # (Runners\MigrateRunner.ps1) et sa bande suit le voyage — les instances
    # s'archivent une par une, les archives voyagent, la racine s'écrit ; la
    # sentinelle lit la fin au journal, comme pour les gestes des lignes.
    hidden [void] Settings() {
        $door = $this.Door("Settings")
        if (-not $door) { return }
        $invoked = @($door.Invoke(@()))
        if ($invoked.Count -eq 0) { return }
        $picked = $invoked[0]
        if (-not $picked) { return }

        # Un refus du contrôleur est un ActionResult — sa phrase est le trail.
        if ($picked.PSObject.Properties['Status']) {
            $this.SetStatus("$($picked.Message)", ("$($picked.Status)" -eq "Nok"))
            return
        }

        if ($this.Look) {
            $this.Look.FontFamily = "$($picked.FontFamily)"
            $this.Look.FontSize = [int]$picked.FontSize
            $this.Look.Variant = "$($picked.Variant)"
        }
        $this.ColourSet = if ($picked.ColorTheme) { "$($picked.ColorTheme)" } else { $this.ColourSet }
        $this.WearTheme([BaseViewWpf]::Assets, $this.ColourSet, "$($picked.Variant)")
        $this.Dress($null, 15)
        $this.UpdateThemeButton()
        $this.Reload()

        if ($picked.NewRoot) {
            $this.SetBusy($true, "Moving the fleet to '$($picked.NewRoot)'...")
            $this.LaunchVisible("Migrate", "$($picked.NewRoot)", "", "")
            return
        }

        $setName = if ($this.ColourSet) { $this.ColourSet } else { "default" }
        $this.SetStatus("Window face: '$($picked.FontFamily)' at $($picked.FontSize) pt, theme '$setName'. Popups follow on their next open.", $false)
    }

    # La porte d'un nom, ou rien — toutes arrivent liées, aucune n'est due.
    hidden [object] Door([string]$name) {
        if (-not $this.Doors) { return $null }
        $property = $this.Doors.PSObject.Properties[$name]
        if (-not $property) { return $null }
        return $property.Value
    }

    # L'ouvrier d'un geste : Runners\<Geste>Runner.ps1 — un par geste, à
    # trois dossiers de cette vue.
    hidden [string] RunnerPath([string]$verb) {
        return (Join-Path $PSScriptRoot "..\..\..\Runners\$($verb)Runner.ps1")
    }

    # La relecture : la racine (le Réglages a pu la déplacer), puis les lignes.
    hidden [void] Reload() {
        $rootDoor = $this.Door("Root")
        if ($rootDoor) {
            try {
                # Emballée : Invoke rend la valeur nue — [0] sur une CHAÎNE en
                # prend le premier caractère (« d:\wsl » → « d », vécu).
                $this.Root = "$(@($rootDoor.Invoke(@()))[0])"
                $this.Find("TxtRoot").Text = "Root: $($this.Root)"
            } catch { }
        }
        $refresh = $this.Door("Refresh")
        if ($refresh) { $this.Fill(@($refresh.Invoke(@()))) } else { $this.Fill(@()) }
    }

    # Le lancement d'une chose longue : le journal vidé, l'ouvrier caché, la
    # sentinelle posée (400 ms, priorité d'entrée — une priorité de fond
    # s'affamait sous la pompe, mesuré). Le lancement assemble sa ligne à la
    # main, chaque valeur citée : un tableau est joint aveuglément, et un nom
    # qui casse la ligne est refusé ici, avant.
    hidden [void] LaunchJob([string]$verb, [string]$name, [string]$arg1) {
        $worker = $this.RunnerPath($verb)
        $log = Join-Path $env:TEMP "wsl-stack-gui-job.log"
        Remove-Item -LiteralPath $log -ErrorAction SilentlyContinue

        if (-not (Test-ProcessArguments @($verb, $name, $arg1, [BaseViewWpf]::Assets, $this.Root))) {
            $this.SetBusy($false, "")
            $this.SetStatus("The job was not launched: a value carries a double quote or a trailing backslash.", $true)
            return
        }

        $this.Child = Start-Process pwsh -PassThru -WindowStyle Hidden -ArgumentList @(
            "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", "`"$worker`"",
            "`"$name`"", "`"$arg1`"", "`"`"", "`"$([BaseViewWpf]::Assets)`"", "`"$($this.Root)`"")
        $this.JobVerb = $verb
        $this.JobName = $name

        try {
            $this.Poller = [System.Windows.Threading.DispatcherTimer]::new([System.Windows.Threading.DispatcherPriority]::Input)
            $this.Poller.Interval = [TimeSpan]::FromMilliseconds(400)
            $this.Poller.Tag = $this
            $this.Poller.Add_Tick({ param($s, $e) $s.Tag.Tick() })
            $this.Poller.Start()
        } catch {
            $this.SetStatus("Could not start watching the job: $($_.Exception.Message)", $true)
            $this.SetBusy($false, "")
        }
    }

    # Un tour de sentinelle : vivant, il le dit (le compte prouve que le
    # minuteur bat) ; sorti, le journal dit la fin — et quoi qu'il arrive, la
    # bande retombe, la liste se relit, la ligne d'état parle.
    hidden [void] Tick() {
        if ($null -eq $this.Child) { return }
        if (-not $this.Child.HasExited) {
            $this.Ticks++
            $this.SetStatus("The $($this.JobVerb.ToLower()) of '$($this.JobName)' - running - tick $($this.Ticks)", $false)
            return
        }

        $ending = ""
        $alert = $false
        $keepLog = $false
        $log = Join-Path $env:TEMP "wsl-stack-gui-job.log"
        try {
            $this.Poller.Stop()
            $this.Ticks = 0

            $trail = @(Get-Content -LiteralPath $log -ErrorAction SilentlyContinue)
            $ok = @($trail | Where-Object { $_ -like "*RESULT OK *" } | Select-Object -Last 1)
            $bad = @($trail | Where-Object { $_ -like "*RESULT FAIL *" } | Select-Object -Last 1)
            if ($bad.Count -gt 0) {
                $ending = "Failed to $($this.JobVerb.ToLower()) '$($this.JobName)': " + ($bad[0] -replace "^.*?RESULT FAIL ", "")
                $alert = $true
            } elseif ($ok.Count -gt 0) {
                $ending = ($ok[0] -replace "^.*?RESULT OK ", "")
            } else {
                $ending = "The $($this.JobVerb.ToLower()) of '$($this.JobName)' ended (exit $($this.Child.ExitCode)) with no result in the trail ($log)."
                $alert = $true
                $keepLog = $true
            }
        } catch {
            $ending = "The watcher failed: $($_.Exception.Message)"
            $alert = $true
        } finally {
            $this.Child = $null
            $this.SetBusy($false, "")
            $this.Reload()
            if ($ending) { $this.SetStatus($ending, $alert) }
            if (-not $keepLog) { Remove-Item -LiteralPath $log -ErrorAction SilentlyContinue }
        }
    }

    # Une console qu'on regarde : pas de journal, pas de guet — le déroulé est
    # là, sous les yeux.
    hidden [void] LaunchVisible([string]$verb, [string]$name, [string]$arg1, [string]$arg2) {
        $worker = $this.RunnerPath($verb)
        if (-not (Test-ProcessArguments @($verb, $name, $arg1, $arg2, [BaseViewWpf]::Assets, $this.Root))) {
            $this.SetStatus("The job was not launched: a value carries a double quote or a trailing backslash.", $true)
            return
        }
        $this.ConsoleChild = Start-Process pwsh -PassThru -ArgumentList @(
            "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$worker`"",
            "`"$name`"", "`"$arg1`"", "`"$arg2`"", "`"$([BaseViewWpf]::Assets)`"", "`"$($this.Root)`"")
        $this.ConsoleWatch = [System.Windows.Threading.DispatcherTimer]::new([System.Windows.Threading.DispatcherPriority]::Input)
        $this.ConsoleWatch.Interval = [TimeSpan]::FromMilliseconds(1000)
        $this.ConsoleWatch.Tag = $this
        $this.ConsoleWatch.Add_Tick({ param($s, $e) $s.Tag.ConsoleTick() })
        $this.ConsoleWatch.Start()
    }

    # La naissance, visible elle aussi, mais guettée : sa fin relit la liste —
    # la nouvelle instance s'y montre sans qu'on touche à rien.
    hidden [void] LaunchBuild([string]$name, [string]$json) {
        $worker = $this.RunnerPath("Build")
        if (-not (Test-ProcessArguments @("Build", $name, $json, [BaseViewWpf]::Assets, $this.Root))) {
            $this.SetStatus("The build was not launched: a value carries a double quote or a trailing backslash.", $true)
            return
        }
        $this.ConsoleChild = Start-Process pwsh -PassThru -ArgumentList @(
            "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$worker`"",
            "`"$name`"", "`"$json`"", "`"`"", "`"$([BaseViewWpf]::Assets)`"", "`"$($this.Root)`"")

        $this.ConsoleWatch = [System.Windows.Threading.DispatcherTimer]::new([System.Windows.Threading.DispatcherPriority]::Input)
        $this.ConsoleWatch.Interval = [TimeSpan]::FromMilliseconds(1000)
        $this.ConsoleWatch.Tag = $this
        $this.ConsoleWatch.Add_Tick({ param($s, $e) $s.Tag.ConsoleTick() })
        $this.ConsoleWatch.Start()
        $this.SetBusy($true, "Creating '$name' in terminal.")
    }

    # La console visible rendue : la fenêtre relit la flotte — la racine a pu
    # changer (le migrate), l'instance naître (la build).
    hidden [void] ConsoleTick() {
        if ($null -eq $this.ConsoleChild -or -not $this.ConsoleChild.HasExited) { return }
        $this.ConsoleWatch.Stop()
        $this.ConsoleChild = $null
        $this.SetBusy($false, "")
        # Le monde en mémoire suit la racine que la console vient peut-être
        # d'écrire (le migrate) : les services re-pointent, PUIS la liste.
        $reroot = $this.Door("ReRoot")
        if ($reroot) { try { $null = $reroot.Invoke(@()) } catch { } }
        $this.Reload()
        $this.SetStatus("Done - the fleet was reread.", $false)
    }

    # La ligne dit qu'elle travaille : ses icônes cèdent la place au petit
    # ruban. Cosmétique, et gardé — la chose ne doit jamais en dépendre.
    hidden [void] MarkRow([object]$button) {
        try {
            $button.Parent.Visibility = [System.Windows.Visibility]::Collapsed
            $button.Parent.Parent.Children[1].Visibility = [System.Windows.Visibility]::Visible
        } catch { }
    }

    # Le tableau : une ligne par inscrite, une par archive, l'alphabet d'un
    # bout à l'autre — l'instance avant son archive du même nom. La taille est
    # celle que la liste sait dire (l'outil partagé), l'archive se dit par sa
    # ligne (son IsArchive décide quels boutons tiennent).
    hidden [void] Fill([object[]]$rows) {
        $list = $this.Find("LstInstances")
        $list.Items.Clear()
        try {
            $sorted = @($rows | Where-Object { $null -ne $_ } | Sort-Object -Property Name -Stable)
            foreach ($row in $sorted) {
                $null = $list.Items.Add([PSCustomObject]@{
                    Name      = "$($row.Name)"
                    Size      = Format-Size ([double]$row.Size)
                    IsArchive = [bool]$row.IsArchive
                })
            }

            # Une colonne Auto d'une GridView se mesure UNE fois puis se fige :
            # après une restauration, un retour des Réglages ou une autre,
            # police, la fenêtre suivait une largeur gelée (vécu). On relance
            # la mesure à chaque remplissage — les colonnes Auto seules.
            foreach ($column in $list.View.Columns) {
                if ([double]::IsNaN($column.Width)) { $column.Width = 0; $column.Width = [double]::NaN }
            }

            if ($sorted.Count -eq 0) {
                $this.SetStatus("No WSL Stack instances found.", $false)
                return
            }
            $this.SetStatus("$($sorted.Count) row(s) loaded.", $false)
        } catch {
            $this.SetStatus("Error reading instances: $($_.Exception.Message)", $true)
        }
    }

    # La ligne d'état, deux voix : les nouvelles, et le rouge du refus.
    hidden [void] SetStatus([string]$message, [bool]$alert) {
        $txt = $this.Find("TxtStatus")
        $brush = if ($alert) { "AppDangerBrush" } else { "AppNewsBrush" }
        $txt.Foreground = $this.FindResource($brush)
        $txt.Text = $message
    }

    # La bande et les mains liées, pour tout ce qui dure.
    hidden [void] SetBusy([bool]$busy, [string]$message) {
        $band = $this.Find("PrgWork")
        $band.Visibility = if ($busy) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
        $this.Find("BtnRefresh").IsEnabled = -not $busy
        $this.Find("LstInstances").IsEnabled = -not $busy
        if ($message) { $this.SetStatus($message, $false) }
    }

    # Le bouton du thème : éteint quand le thème n'a pas de version claire, et
    # son icône montre ce qu'un clic apporte — un soleil tant qu'il fait sombre,
    # une lune tant qu'il fait clair.
    hidden [void] UpdateThemeButton() {
        $button = $this.Find("BtnTheme")
        $button.IsEnabled = $this.ThemeHasLight([BaseViewWpf]::Assets, $this.ColourSet)
        $light = if ($this.Look) { "$($this.Look.Variant)" -eq "Light" } else { $false }
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
