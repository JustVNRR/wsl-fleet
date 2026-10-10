# ==============================================================================
# PACKS: WHAT THE CHECKOUT CARRIES, WHAT AN INSTANCE HAS, HOW ONE TRAVELS
# ==============================================================================
# A pack is a folder, installed when its folder is in ~/.config/packs, and its
# folder is the only thing that travels: add_pack copies it in and runs its
# install.sh there; remove_pack runs remove.sh, takes the folder back out, and
# the pack's leftovers on the system side are cleaned up after.
#
# Add, remove, and the bulk command share these moves - they are here once, for
# the same reason the instance helpers live in WslStack.Instance.psm1: a second
# copy is how the copies start. Nothing here sends a bash script as text
# through wsl.exe: only plain paths, one argument at a time.
# ==============================================================================

# The class this family names - the catalog below is a [WslPackCatalog] -
# pulled in by the file itself: `using` resolves it for every function here,
# whoever called in what shape (measured in the questions next door).
using module ..\WslModel\WslModel.psd1

# Where the packs live now, and the cleanup script. The packs are DATA: the
# catalogue reads assets\packs - editable, deletable - seeded once from the
# repository's own src\distro\packs. Only the DIRECTORIES travel: a pack is a
# folder, and the cleanup script is machinery - it stays the repository's own,
# never copied, always run from here. Both paths are read at load time, not
# inside the functions: $PSScriptRoot means the file being executed, and a
# function belongs to whichever script called it.
$RepoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$SourcePacksRoot = Join-Path $RepoRoot "src\distro\packs"
$PacksRoot = Join-Path $RepoRoot "assets\packs"
$OrphanCleanupScript = Join-Path $SourcePacksRoot "cleanup_orphans.sh"

# The seed: the first import on a machine without a packs folder fills it
# with the repository's own - once, silently. Deleting assets\packs brings
# the base packs back the same way; what was edited or added there is gone
# with it, which is the price of a folder of one's own.
if (-not (Test-Path $PacksRoot) -and (Test-Path $SourcePacksRoot)) {
    $null = New-Item -ItemType Directory -Path $PacksRoot -Force
    foreach ($PackDir in (Get-ChildItem -Path $SourcePacksRoot -Directory)) {
        Copy-Item -LiteralPath $PackDir.FullName -Destination $PacksRoot -Recurse
    }
}

# The catalog of packs this checkout carries, read by the model: the line a
# menu shows, the folder to copy from, the declarations both checklists read -
# and the two resolutions. One list, so add_pack, the checklist and the run
# cannot disagree about what travels with what.
function Get-PackCatalog {
    param([string]$Root = $PacksRoot)
    return [WslPackCatalog]::new($Root)
}

# The folder the packs live in, for the factory: the manager is handed its
# catalogue the way it is handed its root - decided here, at the one place
# that knows the repository's layout.
function Get-PacksRoot {
    return $PacksRoot
}

# A pack is its folder WITH its pack.conf: that is what the gmake side counts
# (packs_list), and the two sides must answer the same thing. A copy that failed
# once left its empty folder behind and they disagreed; the folder is taken back
# now, and this definition makes older ones harmless too.
#
# Wrap the call in @(): PowerShell unrolls a one-element list into its element,
# and the caller then holds a string - where [0] is its first LETTER, not the
# pack. Cost of the other way: a menu that offers 'g'.
function Get-InstalledPacks {
    param([string]$DistroName, [string]$PacksDirectory)
    $Found = Get-InInstanceOutput -DistroName $DistroName -Command @("find", $PacksDirectory, "-mindepth", "2", "-maxdepth", "2", "-name", "pack.conf")
    return @($Found | ForEach-Object { ($_ -replace "/pack.conf$", "").Split("/")[-1] } | Sort-Object)
}

# Where a pack's folder is, once it is in the instance. One place, so that the
# three commands cannot disagree about where a pack lives.
function Get-PackFolder {
    param([string]$PacksDirectory, [string]$Name)
    return "$PacksDirectory/$Name"
}

# Does the pack carry that script? Asked before anything is promised: a pack
# installed before packs had a remove.sh is one whose folder can leave, but
# nothing of it will be undone on the system side.
function Test-PackScript {
    param([string]$DistroName, [string]$Target, [string]$Script, [ref]$ExitCode)

    Invoke-InInstance -DistroName $DistroName -Command @("test", "-f", "$Target/$Script") -ExitCode $ExitCode -Quiet
    return ($ExitCode.Value -eq 0)
}

# Copy a pack's folder into the instance - the whole of what "travelling"
# means. Two ways in, decided by asking the instance first:
#   - the usual one: the pack's Windows folder becomes the working directory
#     (`--cd` has WSL translate it through the mounted drives), and `.` is all
#     there is to name - no wslpath, which the instance does not carry;
#   - with the drives unmounted, `--cd` cannot be honoured and the first way
#     ends on "cannot copy a directory into itself": Windows' own share into
#     the running distro, \\wsl.localhost\<distro>, needs no drive.
#
# The test is the path's presence under /mnt, so the drive letter decides.
# Whichever way it travelled, the scripts are made executable: the Windows side
# has no Unix bit to carry.
function Copy-PackIntoInstance {
    param([string]$DistroName, [string]$PackPath, [string]$Target, [ref]$ExitCode)

    Invoke-InInstance -DistroName $DistroName -Command @("mkdir", "-p", $Target) -ExitCode $ExitCode -Quiet
    if ($ExitCode.Value -ne 0) { return $false }

    $ThroughTheDrives = "/mnt/" + $PackPath.Substring(0, 1).ToLower() + ($PackPath.Substring(2) -replace "\\", "/")
    Invoke-InInstance -DistroName $DistroName -Command @("test", "-d", $ThroughTheDrives) -ExitCode $ExitCode -Quiet

    $Copied = $false
    if ($ExitCode.Value -eq 0) {
        # | Out-Host for the reason written above Invoke-PackScript: this
        # function answers a value, and the copy must not speak through it.
        Invoke-InInstance -DistroName $DistroName -Command @("cp", "-r", ".", "$Target/") -WorkingDirectory $PackPath -ExitCode $ExitCode | Out-Host
        $Copied = ($ExitCode.Value -eq 0)
    } else {
        $Unc = "\\wsl.localhost\$DistroName" + ($Target -replace "/", "\")
        try {
            Copy-Item -Path (Join-Path $PackPath "*") -Destination $Unc -Recurse -Force -ErrorAction Stop
            $Copied = $true
            $ExitCode.Value = 0
        } catch {
            Write-Host "  * pack copy  : the drives are unmounted here, so the pack went through Windows' own share - and Windows refused: $($_.Exception.Message)" -ForegroundColor (Get-MessageColour warning)
            $ExitCode.Value = 1
        }
    }

    if ($Copied) {
        # The globs travel single-quoted inside a `sh -c`: bare arguments are
        # at the mercy of how wsl.exe hands the command over, and one of the
        # ways globs them - where nothing matches, the shell stops, and the
        # pack arrives with every script unexecutable without a word.
        Invoke-InInstance -DistroName $DistroName -Command @("sh", "-c", "find '$Target' -name '*.sh' -exec chmod +x {} +") -ExitCode $ExitCode -Quiet
        # And it is checked rather than trusted: a script that cannot run is a
        # pack that fails on its first target, far from where it went wrong.
        $Still = @(Get-InInstanceOutput -DistroName $DistroName -Command @("sh", "-c", "find '$Target' -name '*.sh' ! -perm -u+x"))
        if ($Still.Count -gt 0) {
            Write-Host "  * pack copy  : some scripts arrived without their executable bit - one command fixes them:" -ForegroundColor (Get-MessageColour warning)
            Write-Host "                 find ~/.config/packs -name '*.sh' -exec chmod +x {} +" -ForegroundColor (Get-MessageColour hint)
        }
    } else {
        # A failed copy leaves nothing behind: the empty folder would make
        # add_pack call the pack present while the gmake side calls it absent.
        # The copy's own exit code is what the caller reports, so it is kept.
        $CopyCode = $ExitCode.Value
        Remove-PackFolder -DistroName $DistroName -Target $Target -ExitCode $ExitCode
        $ExitCode.Value = $CopyCode
    }
    return $Copied
}

# Run one of the pack's own scripts from inside its folder. Output streams to
# the HOST, and that word is the point: the callers write this function's result
# into a variable, and a captured function captures whatever its own calls print
# too - that is how a pack's install went SILENT, everything the script said
# going into the variable that held the answer. Out-Host writes to the screen
# and leaves the value where it was. (It may ask for a password - another
# reason the lines must reach the console.)
# -AsRoot, for the remove.sh scripts: through this tool sudo's question never
# crossed the pipe (its prompt carries no line of its own, and the capture only
# ever showed whole lines), so the call hung on a password nobody could type.
# A removal only takes things away, so the script runs as root, with the user's
# home in HOME so the files it names are still theirs.
function Invoke-PackScript {
    param([string]$DistroName, [string]$Target, [string]$Script, [ref]$ExitCode, [switch]$AsRoot, [string]$ErrorLog = "")

    # 2>&1 then a filter: everything still streams to the screen (Out-Host,
    # nothing buffered), and the error channel alone - where env, bash and
    # apt speak - is also written to $ErrorLog.
    if ($AsRoot) {
        # Not named $home: the automatic is read-only, and the assignment throws.
        $UserHome = Get-InstanceHome -DistroName $DistroName
        Invoke-InInstance -DistroName $DistroName -Command @("env", "HOME=$UserHome", "bash", $Script) `
            -WorkingDirectory $Target -RunAs "root" -ExitCode $ExitCode 2>&1 | ForEach-Object {
                if ($ErrorLog -and $_ -is [System.Management.Automation.ErrorRecord]) { Add-Content -Path $ErrorLog -Value "$_" }
                $_
            } | Out-Host
        return
    }

    Invoke-InInstance -DistroName $DistroName -Command @("bash", $Script) -WorkingDirectory $Target -ExitCode $ExitCode 2>&1 | ForEach-Object {
        if ($ErrorLog -and $_ -is [System.Management.Automation.ErrorRecord]) { Add-Content -Path $ErrorLog -Value "$_" }
        $_
    } | Out-Host
}

# The passwordless door, opened for a run: WSL trusts its Windows side with
# root and no password (wsl -u root), and the pack scripts run as the
# instance's user - their files must be his. The installs' root halves run
# before this door, as WSL's own root; what it opens for is the install.sh
# half, which needs apt to ask nothing while it runs the user's own steps.
# Nothing of it remains once the run ends.
#
# Written through visudo's own check, never beside it: a broken rule in
# /etc/sudoers.d breaks sudo itself. -Quiet: the answer is this function's.
function Enable-PackSudo {
    param([string]$DistroName)

    $User = Split-Path -Leaf (Get-InstanceHome -DistroName $DistroName)
    if (-not $User) { return $false }
    $Command = "printf '%s`n' '$User ALL=(ALL) NOPASSWD: ALL' > /tmp/wsl-stack-pack-sudo" +
        " && chmod 0440 /tmp/wsl-stack-pack-sudo" +
        " && visudo -cf /tmp/wsl-stack-pack-sudo > /dev/null" +
        " && mv /tmp/wsl-stack-pack-sudo /etc/sudoers.d/90-wsl-stack-packs"

    $Code = 0
    Invoke-InInstance -DistroName $DistroName -Command @("bash", "-c", $Command) -RunAs "root" -ExitCode ([ref]$Code) -Quiet
    return ($Code -eq 0)
}

function Disable-PackSudo {
    param([string]$DistroName)

    $Code = 0
    Invoke-InInstance -DistroName $DistroName -Command @("rm", "-f", "/etc/sudoers.d/90-wsl-stack-packs") -RunAs "root" -ExitCode ([ref]$Code) -Quiet
}

# The folder, and with it the pack: the Makefile loads whatever folder is there,
# so a folder that stays is a pack that stays.
function Remove-PackFolder {
    param([string]$DistroName, [string]$Target, [ref]$ExitCode)
    Invoke-InInstance -DistroName $DistroName -Command @("rm", "-rf", $Target) -ExitCode $ExitCode -Quiet
}

# Folders this run placed but never installed - taken back out with the failure
# that stopped the run, because the folder is what the menu reads: one left
# behind passes for an installation that never happened. The folder alone,
# never remove.sh: nothing of the pack reached the system, so there is nothing
# to undo.
function Remove-PlacedFolders {
    param([string]$DistroName, [string]$PacksDirectory, [object[]]$Packs, [ref]$ExitCode)
    foreach ($Pack in $Packs) {
        if ($null -eq $Pack) { continue }
        $Target = Get-PackFolder -PacksDirectory $PacksDirectory -Name $Pack.Name
        Remove-PackFolder -DistroName $DistroName -Target $Target -ExitCode $ExitCode
    }
}

# What the pack left on the system side: what its remove.sh did not name - the
# DEPENDENCIES nobody owns. The script asks apt and ldd, and only then removes;
# it travels the way a pack does - a copy, then a plain path.
function Invoke-PackOrphanCleanup {
    param([string]$DistroName, [ref]$ExitCode)

    if (-not (Test-Path $OrphanCleanupScript)) {
        # Nothing to run: the caller says so rather than pretend it happened.
        return $false
    }

    $RemoteScript = "/tmp/cleanup_orphans.sh"
    $Sent = 0
    # The copy's working directory is the script's OWN folder, wherever it
    # lives: the old $PSScriptRoot named this module's folder, where the
    # file never sat - the copy failed there, silently (measured when the
    # script came home to the packs).
    Invoke-InInstance -DistroName $DistroName -Command @("cp", "cleanup_orphans.sh", $RemoteScript) `
        -WorkingDirectory (Split-Path $OrphanCleanupScript -Parent) -ExitCode ([ref]$Sent) -Quiet
    if ($Sent -ne 0) { return $false }

    Invoke-PackScript -DistroName $DistroName -Target "/tmp" -Script "cleanup_orphans.sh" -ExitCode $ExitCode -AsRoot
    $Cleaned = $ExitCode.Value

    $Gone = 0
    Invoke-InInstance -DistroName $DistroName -Command @("rm", "-f", $RemoteScript) -ExitCode ([ref]$Gone) -Quiet
    return ($Cleaned -eq 0)
}

