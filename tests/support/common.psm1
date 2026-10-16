# The suites' common ground: one Check, one set of stand-ins - every suite
# keeps its own world and its own scenes; the mechanics live here, once.
#
# A module, not a dot-sourced file: the fakes are CLASSES, and a class only
# travels through `using module` (measured).
#
# Check counts in $global:Failures, not $script: on purpose: a module
# function's $script: scope is the MODULE's, and the suites read the counter
# at their own root - the global one is the only one both see.
using module ..\..\src\windows\Repositories\WslRepository.psm1
using module ..\..\src\windows\Repositories\DockerRepository.psm1
using module ..\..\src\windows\Entities\WslInstance.psm1

function Check {
    param([string]$Name, $Got, $Expected)
    if ("$Got" -eq "$Expected") {
        Write-Output "OK   $Name"
    } else {
        Write-Output "FAIL $Name : expected '$Expected', got '$Got'"
        $global:Failures++
    }
}

# The instance side of wsl, faked whole: every call the gestures make is
# recorded in the order it is made - recorded in the real wsl's spelling
# (--terminate, --export...), one convention for every suite. The fields
# cover every world a suite builds; a suite sets only the ones it needs.
class FakeWsl : WslRepository {
    [System.Collections.Generic.List[string]]$Called
    [string[]]$Distros = @()
    [string[]]$Running = @()
    [hashtable]$Folders = @{}
    [string]$TerminateRefusal = ""
    [string]$TruncateVhdx = ""
    [string[]]$Installed = @()
    [string]$Home = "/home/u"
    [bool]$HasRoot = $false
    [bool]$HasRemove = $true
    [string]$FailScript = ""
    [int]$FailCode = 1
    [int]$FailAfter = 1
    [int]$FailSeen = 0

    FakeWsl() : base([System.IO.Path]::GetTempPath()) {
        $this.Called = [System.Collections.Generic.List[string]]::new()
    }

    [WslInstance[]] GetAllDistros() {
        $found = @()
        foreach ($name in @($this.Distros)) {
            $instance = [WslInstance]::new()
            $instance.SetName($name)
            $found += $instance
        }
        return @($found)
    }

    [string[]] GetRunningNames() { return @($this.Running) }
    [string] GetFolder([string]$distroName) {
        if ($this.Folders.ContainsKey($distroName)) { return $this.Folders[$distroName] }
        return ""
    }
    [void] Terminate([string]$instanceName) {
        $this.Called.Add("--terminate $instanceName")
        if ($this.TerminateRefusal) { throw $this.TerminateRefusal }
    }
    [void] TerminateQuietly([string]$instanceName) { $this.Called.Add("--terminate $instanceName") }
    [void] Unregister([string]$instanceName) { $this.Called.Add("--unregister $instanceName") }
    [void] Start([string]$instanceName) { $this.Called.Add("-d $instanceName --exec /bin/true") }
    [void] OpenProfile([string]$instanceName) { $this.Called.Add("open-profile $instanceName") }
    [void] OpenBareShell([string]$instanceName) { $this.Called.Add("open-bare $instanceName") }
    [void] Compact([string]$instanceName) {
        $this.Called.Add("--manage $instanceName --compact")
        # The compaction that really surrenders space: the scene's disk
        # shrinks during the call, like the real one.
        if ($this.TruncateVhdx) { Set-Content -Path $this.TruncateVhdx -Value "x" -NoNewline }
    }
    [void] Export([string]$instanceName, [string]$tarPath, [string]$format) { $this.Called.Add("--export $instanceName $tarPath --format $format") }
    [void] Import([string]$instanceName, [string]$folder, [string]$tarPath) {
        # The real import creates the folder: the stand-in does the same, else
        # the first write that follows has nowhere to go.
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        $this.Called.Add("--import $instanceName $folder $tarPath --version 2")
    }

    # The packs side: the home, the installed list, the copies and the
    # scripts - a framed failure counts its calls, so a suite can make the
    # second copy fail where the first passed.
    [string] GetHome([string]$instanceName) {
        $this.Called.Add("home")
        return $this.Home
    }
    [string] GetFamily([string]$instanceName) { return "debian" }
    [string[]] GetInstalledPacks([string]$instanceName, [string]$packsDirectory) {
        $this.Called.Add("installed")
        return @($this.Installed)
    }
    [int] CopyFolderIntoInstance([string]$instanceName, [string]$sourceFolder, [string]$target) {
        $this.Called.Add("copy-to $target")
        if ($this.FailScript -eq "copy") {
            $this.FailSeen++
            if ($this.FailSeen -ge $this.FailAfter) { return $this.FailCode }
        }
        $leaf = Split-Path -Leaf $target
        if ($this.Installed -notcontains $leaf) { $this.Installed = @($this.Installed) + $leaf }
        return 0
    }
    [int] CopyFileIntoInstance([string]$instanceName, [string]$sourceFile, [string]$targetPath) {
        $this.Called.Add("refresh $targetPath")
        return 0
    }
    [bool] HasInInstance([string]$instanceName, [string]$path) {
        $this.Called.Add("has $path")
        if ($path -like "*install_root.sh") { return $this.HasRoot }
        if ($path -like "*remove.sh") { return $this.HasRemove }
        return $false
    }
    [int] RunScriptInInstance([string]$instanceName, [string]$workingDirectory, [string]$script, [bool]$asRoot, [string]$errorLog) {
        $who = if ($asRoot) { "root" } else { "user" }
        $this.Called.Add("script $workingDirectory $script $who")
        if ($script -eq $this.FailScript) {
            $this.FailSeen++
            if ($this.FailSeen -ge $this.FailAfter) { return $this.FailCode }
        }
        return 0
    }
    [int] RemoveFolderInInstance([string]$instanceName, [string]$target) {
        $this.Called.Add("rm-folder $target")
        $leaf = Split-Path -Leaf $target
        $this.Installed = @($this.Installed | Where-Object { $_ -ne $leaf })
        return 0
    }
    [bool] OpenPackSudoWindow([string]$instanceName) {
        $this.Called.Add("door-open")
        return $true
    }
    [void] ClosePackSudoWindow([string]$instanceName) {
        $this.Called.Add("door-close")
    }
    [bool] RunOrphanCleanup([string]$instanceName) {
        $this.Called.Add("orphan-cleanup")
        return $true
    }
}

# Docker, faked whole: the rides and the desktop's settings - a suite sets
# what it asks about.
class FakeDocker : DockerRepository {
    [System.Collections.Generic.List[string]]$Called
    [bool]$Running = $true
    [bool]$StartOk = $true
    [bool]$RestartOk = $true
    [hashtable]$States = @{}
    [bool]$Readable = $true
    [hashtable]$RegistryVerdict = @{ Ok = $false; Why = "no such image or tag on Docker Hub" }
    [string]$BuilderRefusal = "the builder refused"
    [object[]]$SavedImages = @()

    FakeDocker() : base([System.IO.Path]::GetTempPath()) {
        $this.Called = [System.Collections.Generic.List[string]]::new()
    }

    [bool] TestRunning() {
        $this.Called.Add("running")
        return $this.Running
    }
    [bool] StartDesktop() {
        $this.Called.Add("start")
        return $this.StartOk
    }
    [bool] RestartDesktop() { $this.Called.Add("restart"); return $this.RestartOk }
    [hashtable] TestRegistryImage([string]$reference) {
        $this.Called.Add("registry $reference")
        return $this.RegistryVerdict
    }
    [object[]] GetAllSavedImages() { return @($this.SavedImages) }
    [void] Build([string]$tag, [string]$dockerfile, [string]$context) {
        $this.Called.Add("build $tag $dockerfile $context")
        if ($this.BuilderRefusal) { throw $this.BuilderRefusal }
    }
    [object] GetDesktopNames() {
        if (-not $this.Readable) { return $null }
        $names = @()
        foreach ($key in @($this.States.Keys)) {
            if ("$($this.States[$key])" -eq "yes") { $names += "$key" }
        }
        return @($names)
    }
    [string] GetDesktopState([string]$instanceName) {
        if (-not $this.Readable) { return "unknown" }
        if ($this.States.ContainsKey($instanceName)) { return "$($this.States[$instanceName])" }
        return "no"
    }
    [void] SetDesktopState([string]$instanceName) { $this.Called.Add("set $instanceName"); $this.States[$instanceName] = "yes" }
    [void] RemoveDesktopState([string]$instanceName) { $this.Called.Add("remove $instanceName"); $this.States[$instanceName] = "no" }
}

# The error view: every refusal recorded.
class FakeErrorView {
    [System.Collections.Generic.List[string]]$Orders
    FakeErrorView() { $this.Orders = [System.Collections.Generic.List[string]]::new() }
    [void] Show([string]$failure) { $this.Orders.Add("error $failure") }
}

# The shared "which instance?" view: the answer replayed, everything it was
# shown recorded - Offered and Saw both, whichever a suite reads.
class FakeSelectView {
    [string]$Answer = ""
    [bool]$Asked = $false
    [bool]$Rang = $false
    [object[]]$Offered = @()
    [string]$Saw = ""
    [void] ShowNoInstances() { $this.Rang = $true; $this.Saw = "none" }
    [object] AskOffered([object[]]$offered) {
        $this.Asked = $true
        $this.Offered = @($offered)
        $this.Saw = (@($offered) | ForEach-Object { "$($_.Name)" }) -join ","
        return $this.Answer
    }
}
