# ==============================================================================
# THE ENGINE - THE FLEET, AND NOTHING OF THE SCREEN
# ==============================================================================
# What lives here: the fleet (our instances, the archives, the folders left
# behind), the template's rules (the root, the names, the paths), and one
# method per command of the main menu - the engine side of each: it takes what
# has been CHOSEN and does the work. No question, no line written, no colour.
# This class never talks to anybody.
#
# Who talks to the user, then - the whole wiring, from the way in:
#
#   wsl.ps1                            the menu of the commands, and the
#     |                                dispatch
#     +- src\windows\WslCommands\<command>.ps1
#          |                           the INTERFACE of one command: it asks,
#          |                           hands the answers to the engine, and
#          |                           shows what comes back
#          +- [WslMenu] / [WslConsole]  the asking device (console today)
#          +- $Manager.<Command>(...)   THE ENGINE - this class
#          |     +- [WslInstance]...    the gestures, the state, the disk
#          +- prints the report
#
# The console menu is ONE interface. A graphical one would replace wsl.ps1,
# the scripts and the asking device - and call the same methods below,
# unchanged. The engine does not know there is a console at all.
#
# The contract, one line each:
#   - a method takes the CHOSEN things (an instance, a name, a pack) - it
#     never asks for them; the queries above the commands feed the questions;
#   - it ACTS through the model and re-reads what it changed;
#   - it RETURNS a report, or THROWS - the interface decides what either
#     means on screen, messages and exit codes included.
#
# Nothing without a caller lives here: StopAll was cut - no command calls it.
# A method waits until a command calls it.
#
# theme is both, and the split is the same as everywhere: WHAT it edits is a
# gesture of the instance, like a stop, and the engine carries the operations
# (SetFont, SetColourScheme, SetIcon, SetIconImage). HOW it navigates - the
# loop of menus, the samples, the questions - is the interface's, and a
# graphical one would replace that loop whole.
#
# This class loads with the other classes (its only class dependencies are
# WslInstance, WslRecipe, WslTheme, WslState, WslPack and WslPackCatalog);
# the scripts are the thin interface; the menu classes stay interface-side.
# ==============================================================================
# What this one names, declared here, each one of them.
using module .\WslInstance.psm1
using module .\WslRecipe.psm1
using module .\WslTheme.psm1
using module .\WslState.psm1
using module .\WslPack.psm1
using module .\WslPackCatalog.psm1

class WslInstanceManager {
    # The working folder, decided once and kept: %LOCALAPPDATA%\wsl-stack\
    # root.txt remembers the choice. First decision only: the folder our
    # registered instances already live under, when there is exactly one,
    # then D:\WSL when D: exists, the profile's WSL otherwise. A remembered
    # folder that is gone is never silently replaced - two homes is how data
    # seems lost: when the instances still sit under one existing folder,
    # that one is taken up again (the Note says it); with nowhere to point
    # at, it throws.
    static [object] Root() {
        $File = [WslInstanceManager]::RootFile()
        $Saved = ""
        if ($File -and (Test-Path $File)) {
            $Line = Get-Content -LiteralPath $File -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($Line) { $Saved = $Line.Trim().TrimEnd('\') }
        }
        if ($Saved -and (Test-Path $Saved)) { return [PSCustomObject]@{ Root = $Saved; Note = "" } }

        $Homes = [WslInstanceManager]::RootHomes()

        if (-not $Saved) {
            $Decided = if ($Homes.Count -eq 1) { $Homes[0] }
                       elseif (Test-Path "D:\") { "D:\WSL" }
                       else { "$env:USERPROFILE\WSL" }
            [WslInstanceManager]::SaveRoot($File, $Decided)
            return [PSCustomObject]@{ Root = $Decided; Note = "" }
        }

        if ($Homes.Count -eq 1) {
            [WslInstanceManager]::SaveRoot($File, $Homes[0])
            return [PSCustomObject]@{
                Root = $Homes[0]
                Note = "The working folder '$Saved' is gone - taking up '$($Homes[0])' again, where your instances are."
            }
        }

        throw "The working folder '$Saved' is gone, and no existing folder holds your instances."
    }

    # The choice written for the next runs: the command that moves the fleet
    # says where home went. Here, so the memory file's shape stays one
    # place's business.
    static [void] SetRoot([string]$Root) {
        [WslInstanceManager]::SaveRoot([WslInstanceManager]::RootFile(), $Root.TrimEnd('\'))
    }

    # The memory file, and the writing of it. Outside the working folder by
    # necessity - the folder cannot be asked where it is. Without
    # %LOCALAPPDATA% (the sandboxes some suites run in) there is no memory:
    # the rule decides every run.
    hidden static [string] RootFile() {
        if (-not $env:LOCALAPPDATA) { return "" }
        return (Join-Path $env:LOCALAPPDATA "wsl-stack\root.txt")
    }

    hidden static [void] SaveRoot([string]$File, [string]$Root) {
        if (-not $File) { return }
        $null = New-Item -ItemType Directory -Path (Split-Path -Path $File -Parent) -Force
        Set-Content -LiteralPath $File -Value $Root -Encoding utf8NoBOM
    }

    # Where our instances say home is: the parents of our registered ones
    # whose folder still sits there - a folder on a drive that is gone has no
    # vote - reduced to the distinct ones. One answer means home; none or
    # several say nothing.
    hidden static [string[]] RootHomes() {
        $Homes = [System.Collections.Generic.List[string]]::new()
        foreach ($Instance in [WslInstance]::GetAll()) {
            if (-not (Test-Path $Instance.Path)) { continue }
            if (-not (Test-TemplateInstance -Folder $Instance.Path)) { continue }
            $Parent = Split-Path -Path $Instance.Path -Parent
            if (@($Homes | Where-Object { $_ -eq $Parent }).Count -eq 0) { $Homes.Add($Parent) }
        }
        return @($Homes)
    }

    [string]$InstancesRoot
    [string]$ArchivesRoot
    [WslPackCatalog]$Catalog

    # The roads a build can take - the recipe class's own list, handed to the
    # window the way the catalog is: the gui reads this, never the enum.
    [object[]]$BuildTypes = @()

    [WslInstance[]]$Instances = @()

    # Folders under the root carrying the marker that no registered instance
    # claims - what an interrupted removal, or an outside `wsl --unregister`,
    # leaves behind. No command removes them: the list shows them, a hand
    # deletes them.
    [string[]]$ForgottenFolders = @()

    WslInstanceManager([string]$instancesRoot, [string]$packsRoot) {
        $this.InstancesRoot = $instancesRoot.TrimEnd('\')
        $this.ArchivesRoot  = Join-Path $this.InstancesRoot "archives"
        $this.Catalog = [WslPackCatalog]::new($packsRoot)
        $this.BuildTypes = [WslRecipe]::Roads()
        $this.Refresh()
    }

    # =========================================================================
    # DISCOVERY & INVENTORY
    # =========================================================================

    [void] Refresh() {
        $this.Instances = @()
        $this.ForgottenFolders = @()
        $registeredPaths = @()

        # 1. The distributions registered in the Windows registry - ours only:
        # the marker vouches for them, so the held list never shows a distro
        # this template did not make. Their state comes from one batched
        # question - wsl --list says what runs, about everyone at once - not
        # from one wsl.exe per instance.
        $Running = Get-DistroNames -Running
        foreach ($inst in @([WslInstance]::GetAll() | Where-Object { Test-TemplateInstance -Folder $_.Path })) {
            $inst.RefreshArchiveStatus()
            if ($Running -contains $inst.Name) {
                $inst.State = [WslState]::Running
            } else {
                $inst.State = [WslState]::Stopped
            }
            $this.Instances += $inst
            $registeredPaths += $inst.Path
        }

        # 2. Every archive on disk, its name registered or not: an instance
        # at rest - the tar inside its folder, and the look beside it. A
        # same-named archive and live instance sit in the list together, so
        # the pair reads at a glance; the live one comes first. The row
        # takes shape, then answers whether it is a real archive - a folder
        # without a tar is not shown.
        if (Test-Path $this.ArchivesRoot) {
            foreach ($archiveDir in (Get-ChildItem -Path $this.ArchivesRoot -Directory | Sort-Object Name)) {
                $archivedInst = [WslInstance]::new()
                # A folder whose name the class refuses is left out of the
                # list - the name rule lives on the class.
                try { $archivedInst.SetName($archiveDir.Name) } catch { continue }
                $archivedInst.Path = Join-Path $this.InstancesRoot $archiveDir.Name
                $archivedInst.HasArchive = $true
                $archivedInst.ArchivePath = $archiveDir.FullName
                $archivedInst.State = [WslState]::Archived
                if (-not $archivedInst.ArchiveTar()) { continue }

                $this.Instances += $archivedInst
            }
        }

        # 3. Marked folders that no instance claims
        if (Test-Path $this.InstancesRoot) {
            foreach ($folder in (Get-ChildItem -Path $this.InstancesRoot -Directory -ErrorAction SilentlyContinue)) {
                if ((Test-TemplateInstance -Folder $folder.FullName) -and
                    ($registeredPaths -notcontains $folder.FullName)) {
                    $this.ForgottenFolders += $folder.FullName
                }
            }
        }
    }

    # =========================================================================
    # LOOKUP & VALIDATION - WHAT THE QUESTIONS ARE BUILT ON
    # =========================================================================

    # The ones a question can offer: ours, running or stopped - the part of
    # the held list that is not an archive row, by name like every list this
    # fleet ever showed. As fresh as the last Refresh: a caller that needs it
    # fresher says so first.
    [WslInstance[]] WslRegisteredInstances() {
        return @($this.Instances | Where-Object { $_.State -ne [WslState]::Archived } | Sort-Object Name)
    }

    [WslInstance] FindByName([string]$name) {
        return ($this.Instances | Where-Object { $_.Name -eq $name } | Select-Object -First 1)
    }

    [bool] IsNameAvailable([string]$name) {
        return $null -eq $this.FindByName($name)
    }

    # The name rule - asked of the class that owns it, the instance. The
    # callers ask before doing anything; the setter is the last door.
    [bool] IsNameUsable([string]$name) {
        return [WslInstance]::IsNameUsable($name)
    }

    [bool] IsPathOccupied([string]$path) {
        return (Test-Path $path) -and (@(Get-ChildItem -Path $path -Force).Count -gt 0)
    }

    # =========================================================================
    # QUERIES - WHAT FEEDS THE QUESTIONS AND THE REPORTS
    # =========================================================================

    # The packs an instance carries, by name - or $null when it cannot say
    # where its user's home is (the caller says so and stops). The read is the
    # instance's own; the null is the caller's stop signal, kept here.
    [object] InstalledPacks([WslInstance]$Instance) {
        # The instance's own read; the null the callers stop on is this
        # method's signal alone - each caller has its sentence for it.
        try { return @($Instance.GetPacks()) }
        catch { return $null }
    }

    # The packs a question may offer: this checkout carries them, the
    # instance's family fits them, and the instance lacks them. -Offered only
    # - an invisible pack arrives with the pack that requires it, never
    # offered.
    [WslPack[]] CandidatePacks([WslInstance]$Instance) {
        $Installed = @($Instance.GetPacks())
        $Family = Get-InstanceFamily -DistroName $Instance.Name
        return @($this.Catalog.OfferedFor($Family) | Where-Object { $Installed -notcontains $_.Name })
    }

    # The packs this instance carries that a user may take out by hand: the
    # invisible ones leave with the last pack that requires them.
    [string[]] RemovablePacks([WslInstance]$Instance) {
        $Installed = @($Instance.GetPacks())
        $Offered = @()
        foreach ($Name in $Installed) {
            $Pack = $this.Catalog.GetPack($Name)
            if ($null -ne $Pack -and -not $Pack.Offered) { continue }
            $Offered += $Name
        }
        return $Offered
    }

    # What a copy of that instance under that name costs: the copy reads the
    # instance into an archive and unpacks it into the new folder, both at the
    # same time - twice the disk is the peak a caller checks against.
    [object] DuplicationCost([WslInstance]$Instance, [string]$Name) {
        $VhdxPath = Join-Path $Instance.Path "ext4.vhdx"
        $DiskBytes = if (Test-Path $VhdxPath) { (Get-Item $VhdxPath).Length } else { 0 }
        $NeededBytes = 2 * $DiskBytes
        $InstallPath = [System.IO.Path]::GetFullPath((Join-Path $this.InstancesRoot $Name))
        $DriveLetter = (Split-Path -Qualifier $InstallPath).TrimEnd(':')
        $FreeBytes = (Get-PSDrive -Name $DriveLetter).Free
        return [PSCustomObject]@{ DiskBytes = $DiskBytes; NeededBytes = $NeededBytes; FreeBytes = $FreeBytes; DriveLetter = $DriveLetter; InstallPath = $InstallPath }
    }

    # Docker Desktop's answer an archive carries, read from the file beside
    # its tar - the fact a conversation checks before deciding on the Docker
    # question. "" when the archive carries no file.
    [string] ArchiveDocker([string]$ArchiveDir) {
        $Archive = Get-ArchiveInstance -Folder $ArchiveDir
        if (-not $Archive) { return "" }
        return "$($Archive.Docker)"
    }

    # Docker Desktop's answer about one instance, live - the source of a copy
    # carries the answer its recipe captured.
    [string] DockerStateOf([WslInstance]$Instance) {
        return (Get-DockerState -Name $Instance.Name)
    }

    # The instance's system family, live - what a pack question filters with.
    [string] FamilyOf([WslInstance]$Instance) {
        return (Get-InstanceFamily -DistroName $Instance.Name)
    }

    # Whether the Docker question is worth asking at all: Docker knew the
    # original, and does not know this name yet. The conversation asks it
    # before the work, the setup re-checks it before acting - one rule.
    [bool] DockerQuestionDue([string]$Carried, [string]$Name) {
        return (Test-DockerQuestionDue -Carried $Carried -Name $Name)
    }

    # =========================================================================
    # THE MENU'S COMMANDS - ONE METHOD EACH, ENGINE SIDE
    # =========================================================================

    # list - the fleet as it is: ours, the archives on disk, the folders left
    # behind. Read-only, so it can run at any moment. The archive rows are
    # the fleet's own - Refresh dressed them - most recent first; the
    # forgotten folders are dressed here: name, full path, and the disk's
    # size where one still sits inside.
    [object] List() {
        $Archives = @($this.Instances | Where-Object { $_.State -eq [WslState]::Archived } |
            Sort-Object { $_.ArchivedOn() } -Descending)

        $Forgotten = @()
        foreach ($FolderPath in $this.ForgottenFolders) {
            $Folder = Get-Item -Path $FolderPath -ErrorAction SilentlyContinue
            if (-not $Folder) { continue }
            $Forgotten += [PSCustomObject]@{ Name = $Folder.Name; Path = $Folder.FullName; Bytes = [long](Get-VhdxSize $Folder.FullName) }
        }

        return [PSCustomObject]@{
            Instances = @($this.WslRegisteredInstances())
            Archives  = $Archives
            Forgotten = $Forgotten
        }
    }

    # build - the fleet side of it. The command keeps its own scene (the
    # questions, the confirmations, the destruction of an instance it is
    # replacing - its act, and its risk, by the user's own word); what is the
    # fleet's is here: the name and the folder are this template's rules, the
    # creation is the instance's own Build - the recipe in, a complete
    # instance out - and the fleet is re-read after. The name guard asks
    # WINDOWS, live - not the inventory this object read at its birth.
    [WslInstance] CreateNew([string]$name, [WslRecipe]$recipe, [string]$user) {
        if (-not $this.IsNameUsable($name)) {
            throw "'$name' is not usable as an instance name (letters, digits, '.', '_' and '-' only)."
        }
        if ((Get-DistroNames) -contains $name) {
            throw "An instance named '$name' is registered on this machine."
        }

        $installPath = Join-Path $this.InstancesRoot $name
        if ($this.IsPathOccupied($installPath)) {
            throw "Installation folder '$installPath' already exists and is not empty."
        }

        $newInstance = [WslInstance]::Build($name, $installPath, $recipe, $user)
        $this.Refresh()
        return $newInstance
    }

    # start / stop - the menu's engine side, and nothing more than the route:
    # the gesture, the state it moves and the failure it throws all belong to
    # the instance's own Start()/Stop() - the state moves only once the gesture
    # succeeded, and the throw travels. The instance comes back, so a flow can
    # be written as a chain.
    [WslInstance] Start([WslInstance]$Instance) {
        $Instance.Start()
        return $Instance
    }

    [WslInstance] Stop([WslInstance]$Instance) {
        $Instance.Stop()
        return $Instance
    }

    # restart - the two gestures, in the one order that makes the second a
    # fresh boot. A half that fails throws with the half named and the
    # instance's standing said: the interface cannot see inside, and
    # guessing is not its business.
    [WslInstance] Restart([WslInstance]$Instance) {
        try {
            $Instance = $this.Stop($Instance)
        } catch {
            throw "The stop did not complete - '$($Instance.Name)' may still be running, and was not started again. $($_.Exception.Message)"
        }
        try {
            $Instance = $this.Start($Instance)
        } catch {
            throw "The start did not complete - '$($Instance.Name)' is stopped. $($_.Exception.Message)"
        }
        return $Instance
    }

    # shell - the session is a process that owns the console until the user
    # leaves; the exit code is the shell's own, handed back, not interpreted.
    [int] Shell([WslInstance]$Instance) {
        return $Instance.Shell()
    }

    # add_pack - the request, passed on whole: the instance resolves what the
    # pack brings, skips what it already carries, installs the rest behind
    # one door of its own and reports. Nothing is decided here.
    [object] AddPack([WslInstance]$Instance, [string]$PackName) {
        return $Instance.AddPack($PackName, $this.Catalog)
    }

    # remove_pack - the request, passed on whole: the instance resolves what
    # leaves with the pack, refuses a still-claimed one, runs each remove.sh
    # from inside its own folder and tidies the leftovers. Nothing is decided
    # here.
    [object] RemovePack([WslInstance]$Instance, [string]$PackName) {
        return $Instance.RemovePack($PackName, $this.Catalog)
    }

    # add_pack_to_catalog - a new pack in the catalogue, copied from another:
    # the one named, or the template when none is. The name is refused here -
    # a client is not trusted with it, a bad one must not become a folder -
    # then the catalogue holds the copy and the conf rewriting; nothing else
    # is decided here.
    [WslPack] AddPackToCatalog([WslPack]$Source, [string]$NewName, [string]$Description) {
        if (-not $this.IsNameUsable($NewName)) {
            throw "'$NewName' is not usable as a pack name (letters, digits, '.', '_' and '-' only)."
        }
        if ($null -eq $Source) { $Source = $this.Catalog.GetPack("_oh_my_pack") }
        if ($null -eq $Source) {
            throw "The catalogue carries no '_oh_my_pack' - nothing to copy from."
        }
        return $this.Catalog.CreateFrom($Source, $NewName, $Description)
    }

    # remove_pack_from_catalog - the pack's folder leaves, whole. Nothing is
    # decided here.
    [WslPack] RemovePackFromCatalog([string]$Name) {
        return $this.Catalog.Remove($Name)
    }

    # open_pack_folder - the pack's folder, opened as Windows opens folders.
    # The catalogue resolves it, this launches the opener; nothing is decided
    # here.
    [void] OpenPackFolder([string]$Name) {
        $Pack = $this.Catalog.GetPack($Name)
        if ($null -eq $Pack) {
            throw "There is no pack named '$Name' in the catalogue."
        }
        Start-Process -FilePath $Pack.Path
    }

    # manage_packs - what was ticked arrives, what was unticked leaves; the
    # checklist itself is the interface's (prompts.ps1's Select-Packs). The
    # applying is the instance's own act; what stands comes back read from
    # the instance: the folder is the state.
    [object] ManagePacks([WslInstance]$Instance, [WslPack[]]$ToAdd, [string[]]$ToRemove) {
        # The report tells what really happened: the before-and-after read is
        # what makes Added and Removed true names - a run that failed added
        # less than it was asked, and says so.
        $Before = @($Instance.GetPacks())
        $Failure = $Instance.ApplyPacks($ToAdd, $ToRemove)
        $Now = @($Instance.GetPacks())

        return [PSCustomObject]@{
            Failure  = $Failure
            Now      = $Now
            Added    = @($Now | Where-Object { $Before -notcontains $_ })
            Removed  = @($Before | Where-Object { $Now -notcontains $_ })
            ExitCode = if ($null -ne $Failure) { $Failure.ExitCode } else { 0 }
        }
    }

    # unregister - the destruction: the copy first when asked (the instance's
    # own name on disk), then the instance's own Unregister - its stop with
    # the failure ignored, the unregister, the folder, the Windows-side
    # housekeeping. What it found comes back for the report.
    [object] Unregister([WslInstance]$Instance, [bool]$ArchiveFirst) {
        $ArchiveReport = $null
        if ($ArchiveFirst) {
            # The copy is the last moment to keep something: a failed archive
            # stops here, and the sentence says nothing of the instance was
            # touched - the old command said as much before it handed over.
            try {
                $ArchiveReport = $this.Archive($Instance, $Instance.Name, "tar.gz", $true)
            } catch {
                throw "The archive did not complete - nothing was destroyed. $($_.Exception.Message)"
            }
        }

        $Removed = $Instance.Unregister()
        return [PSCustomObject]@{ Archive = $ArchiveReport; Removed = $Removed }
    }

    # Where an archive of that name lives - the one place that spells it.
    [string] ArchiveDirFor([string]$Name) {
        return [System.IO.Path]::GetFullPath((Join-Path $this.ArchivesRoot $Name))
    }

    # The name is taken already, the caller says so and the archive replaces.
    [bool] HasArchive([string]$Name) {
        return (Test-Path $this.ArchiveDirFor($Name))
    }

    # The first free name an archive can take: the instance's own, or the
    # next numbered suffix while it is taken.
    [string] ProposeArchiveName([string]$Name) {
        $Proposal = $Name
        $Suffix = 0
        while (Test-Path $this.ArchiveDirFor($Proposal)) {
            $Suffix++
            $Proposal = "$Name-$Suffix"
        }
        return $Proposal
    }

    # What an archive of that name would cost before it is made: the disk's
    # size and the free room on the target's drive. The copy's plan
    # (DuplicationCost) reads the same way.
    [object] ArchiveCost([WslInstance]$Instance, [string]$Name, [string]$Format) {
        $DiskBytes = $Instance.DiskBytes()
        $Destination = Join-Path $this.ArchiveDirFor($Name) "$Name.$Format"
        $FreeBytes = (Get-PSDrive -Name (Split-Path -Qualifier $Destination).TrimEnd(':')).Free
        return [PSCustomObject]@{ DiskBytes = $DiskBytes; FreeBytes = $FreeBytes; Destination = $Destination }
    }

    # archive - the copy on disk: the export, then the look beside the tar (a
    # partial archive is removed inside the instance's own Archive - left on
    # disk it would look exactly like a backup later on). The instance's own
    # gesture stops it for the export and puts it back, when the caller
    # permits and its state asks for it; the report carries what it had to do.
    [object] Archive([WslInstance]$Instance, [string]$Name, [string]$Format, [bool]$MayStop) {
        if (-not (Test-Path -Path $this.ArchivesRoot)) {
            New-Item -ItemType Directory -Path $this.ArchivesRoot -Force | Out-Null
        }

        $ArchiveDir = $this.ArchiveDirFor($Name)
        $Destination = Join-Path $ArchiveDir "$Name.$Format"

        $Written = $Instance.Archive($Name, $Format, $MayStop, $ArchiveDir)
        $Archive = Get-Item -Path $Destination
        $Look = $Instance.ArchiveLook($ArchiveDir)

        return [PSCustomObject]@{ Name = $Name; ArchiveDir = $ArchiveDir; Destination = $Destination; Archive = $Archive; Look = $Look; Stopped = $Written.Stopped }
    }

    # restore - an archive back on its feet, under a name of its own. The tar
    # does not carry the look; it sits next to it, and State re-applies it.
    # Version 2, like build: a tar does not carry the version it came from,
    # and WSL 1 is not what this repository builds. AddDocker is the callers'
    # word on Docker's entry - the window's hidden job has nobody to ask and
    # passes false. The report carries the instance - in the inventory by now
    # - the setup's own report for the screens, and Docker's answer about it
    # for the endings.
    [object] RestoreFromArchive([string]$ArchiveDir, [string]$Name, [bool]$AddDocker) {
        if (-not $this.IsNameUsable($Name)) {
            throw "'$Name' is not usable as an instance name (letters, digits, '.', '_' and '-' only)."
        }
        # "An instance named X" means a REGISTERED one. IsNameAvailable would
        # not tell: the inventory counts the archives too, and restoring an
        # archive under its own name - the usual case - must not collide with
        # its own entry there.
        if ((Get-DistroNames) -contains $Name) {
            throw "An instance named '$Name' already exists."
        }

        $InstallPath = [System.IO.Path]::GetFullPath((Join-Path $this.InstancesRoot $Name))
        if (Test-Path $InstallPath) {
            throw "A folder with that name already exists: $InstallPath"
        }

        # The newborn itself is not kept: the report below reads the FRESH
        # row, after the look and the refresh - state and recipe off the disk.
        $null = [WslInstance]::Restore($ArchiveDir, $Name, $InstallPath)

        # The look and Docker's entry, which a tar carries neither of - the
        # marker was written by Restore, right after the import. The setup
        # acts the word and reports what it did.
        $Setup = Set-InstanceState -Name $Name -InstallPath $InstallPath -Folder $ArchiveDir -AddDocker $AddDocker
        $this.Refresh()
        return [PSCustomObject]@{ Instance = $this.FindByName($Name); Docker = $Setup.DockerState; Setup = $Setup }
    }

    # delete_archive - the folder and everything in it, gone for good: the
    # tar, the look beside it. The name rule is the instance rule, and here it
    # is also the safety rail: no separator can ride in, so no path can leave
    # the archives folder. No confirmation either - the caller says the name,
    # and the window's gate is the window's own.
    [object] DeleteArchive([string]$Name) {
        if (-not $this.IsNameUsable($Name)) {
            throw "'$Name' is not usable as an archive name (letters, digits, '.', '_' and '-' only)."
        }

        $ArchiveDir = Join-Path $this.ArchivesRoot $Name
        if (-not (Test-Path $ArchiveDir)) {
            throw "There is no archive named '$Name': $ArchiveDir does not exist."
        }

        $Freed = (Get-ChildItem -Path $ArchiveDir -Recurse -File -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
        Remove-Item -LiteralPath $ArchiveDir -Recurse -Force
        $this.Refresh()

        return [PSCustomObject]@{ Name = $Name; ArchiveDir = $ArchiveDir; Freed = [long]$Freed }
    }

    # duplicate - the source is only read; the copy lands under a name of its
    # own, with the look captured before the export and re-applied after. The
    # room comes first, before anything moves: the copy reads the instance
    # into an archive and unpacks it into the new folder at the same time -
    # twice the disk is the peak - and the refusal is spelled here, once, for
    # both roads. The stopping is the instance's own gesture (it goes down for
    # a still disk and comes back up when it went down for the copy), its
    # report saying whether it had to.
    [object] Duplicate([WslInstance]$Instance, [string]$Name, [bool]$AddDocker) {
        if (-not $this.IsNameUsable($Name)) {
            throw "'$Name' is not usable as an instance name (letters, digits, '.', '_' and '-' only)."
        }
        if (-not $this.IsNameAvailable($Name)) {
            throw "An instance named '$Name' already exists."
        }

        # The room, before the stop and the export: the check reads the disk
        # and the free space, no stop needed.
        $Cost = $this.DuplicationCost($Instance, $Name)
        if ($Cost.FreeBytes -lt $Cost.NeededBytes) {
            throw ("Not enough room on {0}: needed {1}, free {2}." -f $Cost.DriveLetter, (Format-Size $Cost.NeededBytes), (Format-Size $Cost.FreeBytes))
        }

        $FullDestination = [System.IO.Path]::GetFullPath((Join-Path $this.InstancesRoot $Name))
        $DestinationDir = Split-Path -Path $FullDestination -Parent
        if (-not (Test-Path -Path $DestinationDir)) {
            New-Item -ItemType Directory -Path $DestinationDir -Force | Out-Null
        }

        # The source is only read; the temporary image is removed by the copy
        # itself, in all cases - it is worth twice the disk. The folder is
        # spelled here, once, and told to the gesture.
        $Copy = $Instance.Duplicate($Name, $FullDestination)

        $CopyVhdx = Join-Path $FullDestination "ext4.vhdx"
        $CopyBytes = if (Test-Path $CopyVhdx) { (Get-Item $CopyVhdx).Length } else { 0 }

        # The copy has its own profile and its own guid: the look is re-applied
        # from the values captured before the export - Docker's entry too,
        # keyed by name. AddDocker is the callers' word (the window's hidden
        # job passes false); the setup acts it and reports.
        $Setup = Set-InstanceState -Name $Name -InstallPath $FullDestination -Recipe $Copy.Recipe -Docker $Copy.Docker -AddDocker $AddDocker
        $this.Refresh()

        # The report carries what the endings say: whether the source went
        # down and back up for the copy, the setup's own report for the
        # screens, and Docker's answer about it.
        return [PSCustomObject]@{ Instance = $this.FindByName($Name); InstallPath = $FullDestination; CopyBytes = $CopyBytes; Stopped = $Copy.Stopped; Docker = $Setup.DockerState; Setup = $Setup }
    }

    # migrate - the archives folder's voyage: from under this root to the one
    # the caller names, a rename on one volume and a robocopy across (the
    # originals kept), the room checked first. Nothing to move is a report
    # too, not an error. The refusals are this method's own words: a target
    # already holding an archives folder, a volume too full, a copy the tool
    # reported broken. The report tells where the target stands, full path
    # included - the root switch is the caller's, after this returns.
    [object] MoveArchives([string]$Target) {
        $TargetFull = [System.IO.Path]::GetFullPath($Target)
        $OldArchives = Join-Path $this.InstancesRoot "archives"
        $NewArchives = Join-Path $TargetFull "archives"
        $Report = [PSCustomObject]@{ Target = $TargetFull; Old = $OldArchives; New = $NewArchives; Moved = $false; Method = ""; Kept = $false }

        if (-not (Test-Path $OldArchives)) { return $Report }

        if (Test-Path $NewArchives) {
            throw "'$NewArchives' already exists - nothing was moved. Move it away first."
        }

        $SourceRoot = [System.IO.Path]::GetPathRoot($this.InstancesRoot)
        $TargetRoot = [System.IO.Path]::GetPathRoot($TargetFull)
        $IsSameVolume = ($SourceRoot.TrimEnd('\').ToUpperInvariant() -eq $TargetRoot.TrimEnd('\').ToUpperInvariant())

        if ($IsSameVolume) {
            try {
                Move-Item -Path $OldArchives -Destination $NewArchives -ErrorAction Stop
            } catch {
                throw "the move failed: $($_.Exception.Message)"
            }
            $Report.Moved = $true
            $Report.Method = "rename"
            return $Report
        }

        $ArchivesSize = (Get-ChildItem -Path $OldArchives -Recurse -Force -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
        $Free = (Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$($TargetRoot.TrimEnd('\'))'").FreeSpace
        if ($Free -lt ($ArchivesSize + 2GB)) {
            throw "not enough free space on '$($TargetRoot.TrimEnd('\'))' - $([Math]::Ceiling(($ArchivesSize + 2GB) / 1GB)) GB needed."
        }

        # /E subdirectories, /COPY:DAT data, attributes and times, /Z
        # restartable (a long copy survives a hiccup), /R:3 /W:2 a short
        # retry. Codes under 8 are success - the tool's own scale, read from
        # the global (a class method's scope does not carry it).
        & robocopy.exe $OldArchives $NewArchives /E /COPY:DAT /Z /R:3 /W:2 | Out-Null
        $Code = $global:LASTEXITCODE
        if ($Code -ge 8) {
            throw "robocopy reported errors (code $Code) - the originals are untouched."
        }
        $Report.Moved = $true
        $Report.Method = "robocopy"
        $Report.Kept = $true
        return $Report
    }

    # shrink - the compact, in place, working on a running instance; it
    # refuses on its own if the disk cannot be compacted. The safety copy,
    # when the user asked for one, is this method's first act: the whole
    # sequence - copy, then compact, and a failed copy stopping everything -
    # is spelled here, once, for both roads. The instance is left the way it
    # was found.
    [object] Shrink([WslInstance]$Instance, [bool]$ArchiveFirst) {
        $ArchiveReport = $null
        if ($ArchiveFirst) {
            try {
                $ArchiveReport = $this.Archive($Instance, $Instance.Name, "tar.gz", $true)
            } catch {
                throw "The archive did not complete - nothing was compacted: $($_.Exception.Message)"
            }
        }

        $WasRunning = ($Instance.State -eq [WslState]::Running)
        $Result = $Instance.Shrink()

        $Restarted = $false
        if ($WasRunning) {
            try { $Instance.Start(); $Restarted = $true } catch { $Restarted = $false }
        }

        return [PSCustomObject]@{
            Archive    = $ArchiveReport
            Before     = $Result.Before
            After      = $Result.After
            Freed      = $Result.Freed
            WasRunning = $WasRunning
            Restarted  = $Restarted
        }
    }

    # =========================================================================
    # THE LOOK - THE INSTANCE'S WEAR, ONE GESTURE AT A TIME
    # =========================================================================
    # Same contract as start/stop, and the same correction: the writes - the
    # profile's guid, the fragment, the look, the recipe kept through (a font
    # or colour change must not eat the tile) - are the INSTANCE's own, next
    # to its ApplyTerminalProfile, which walks the same road. The manager
    # routes and pretends nothing; a machine without the profile throws, and
    # the interface says it.

    [WslInstance] SetFont([WslInstance]$Instance, [string]$FontName) {
        $Instance.SetFont($FontName)
        return $Instance
    }

    [WslInstance] SetColourScheme([WslInstance]$Instance, [string]$SchemeName) {
        $Instance.SetColourScheme($SchemeName)
        return $Instance
    }

    # The drawn recipe comes back from the instance - the drawing settles the
    # parts the recipe left open.
    [object] SetIcon([WslInstance]$Instance, [object]$Drawing) {
        return $Instance.SetIcon($Drawing)
    }

    [WslInstance] SetIconImage([WslInstance]$Instance, [string]$Source) {
        $Instance.SetIconImage($Source)
        return $Instance
    }

    # wslconfig - the machine's own settings file: created commented when
    # there is none, then opened - the whole gesture, the machine picking the
    # application it gives a .wslconfig. A machine with no application set
    # for it fails the opening; the caller holds the words for that.
    [object] WslConfig() {
        $Path = Join-Path $env:USERPROFILE ".wslconfig"
        $Created = $false
        if (-not (Test-Path $Path)) {
            @'
# WSL's Windows-wide settings. Read when the WSL machine starts: `wsl --shutdown`
# then a new start applies a change.
#
# The common keys: https://learn.microsoft.com/windows/wsl/wsl-config
#
# [wsl2]
# memory=8GB          # the machine's memory cap
# processors=4        # the CPUs it may use
# dnsTunneling=true   # WSL answers the DNS itself
'@ | Set-Content -Path $Path -Encoding ascii
            $Created = $true
        }

        # The opening is the gesture's end - same act, same place.
        Start-Process -FilePath $Path
        return [PSCustomObject]@{ Path = $Path; Created = $Created }
    }

}
