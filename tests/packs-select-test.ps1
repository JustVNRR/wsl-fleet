# Drives the pack machinery - the selection rules on the catalogue, the moves
# on the service - with no instance and no terminal.
#
#   The catalogue   is asked directly: what a choice installs (a pack arrives
#                   on top of what it requires, requirements first), what a
#                   removal takes with it (an invisible pack follows its last
#                   claimant), what it would break (a pack still required by a
#                   standing one), and which family each pack is offered to.
#                   The checklist question itself - the boxes, the numbered
#                   answers, the console's refusal - lives in the views now;
#                   the build's own checklist is driven end to end by
#                   build-question-test.
#   The service     is driven through ManagePacks with a stand-in WslRepository
#                   recording every pack move - the one place a pack touches
#                   the instance: copy its folder in, run a script behind the
#                   door, take the folder out, travel the orphan cleanup. The
#                   move names and their ORDER are the design: the newcomer is
#                   placed BEFORE a remove.sh asks its question, so a shared
#                   package is left where it is.
#
# No standard input is read any more: the old answers file is left alone.
#
# Usage:  pwsh -NoProfile -File tests\packs-select-test.ps1
using module ..\src\windows\Model\WslPackCatalog.psm1
using module ..\src\windows\Service\InstanceService.psm1
using module ..\src\windows\Repository\WslRepository.psm1
using module ..\src\windows\Repository\InstanceRepository.psm1
using module ..\src\windows\Repository\PackCatalogRepository.psm1
using module ..\src\windows\Dto\InstanceDto.psm1

# The instance's own side of the moves, faked whole: every pack move answers
# here and is recorded here - the order of the record is what the scenes read.
# The scripts' answers are scripted: $FailScript fails with $FailCode once
# $FailAfter matching calls have gone through, and $HasRoot/$HasRemove say
# whether the instance carries those files.
class FakeWsl : WslRepository {
    [System.Collections.Generic.List[string]]$Called
    [string[]]$Installed = @()
    [string]$Home = "/home/u"
    [string]$FailScript = ""
    [int]$FailCode = 1
    [int]$FailAfter = 1
    [int]$FailSeen = 0
    [bool]$HasRoot = $true
    [bool]$HasRemove = $true

    FakeWsl() : base([System.IO.Path]::GetTempPath()) {
        $this.Called = [System.Collections.Generic.List[string]]::new()
    }

    [string] GetHome([string]$instanceName) {
        $this.Called.Add("home")
        return $this.Home
    }

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

$Failures = 0
function Check {
    param([string]$Name, $Got, $Expected)
    if ("$Got" -eq "$Expected") {
        Write-Output "OK   $Name"
    } else {
        Write-Output "FAIL $Name : expected '$Expected', got '$Got'"
        $script:Failures++
    }
}

# The catalogue as the service builds it: the declarations are read from the
# repository - the folder walk lives there - then posed on the rules.
function New-Catalog {
    param([string]$Root)
    $catalog = [WslPackCatalog]::new()
    $catalog.SetPacks(@([PackCatalogRepository]::new($Root).GetAllPacks()))
    return $catalog
}

function New-PackRoot {
    param([object[]]$Declarations)
    $Root = Join-Path ([System.IO.Path]::GetTempPath()) ("packs-select-" + [Guid]::NewGuid().ToString("N"))
    foreach ($Declaration in $Declarations) {
        $Folder = Join-Path $Root $Declaration.Name
        New-Item -ItemType Directory -Path $Folder -Force | Out-Null
        $Conf = @("PACK_DESCRIPTION := $($Declaration.Description)")
        if ($Declaration.Requires) { $Conf += "PACK_REQUIRES := $($Declaration.Requires)" }
        if ($Declaration.Visible) { $Conf += "PACK_VISIBLE := $($Declaration.Visible)" }
        if ($Declaration.Family) { $Conf += "PACK_FAMILY := $($Declaration.Family)" }
        Set-Content -Path (Join-Path $Folder "pack.conf") -Value $Conf
    }
    return $Root
}

# The catalog, built from a packs folder of this test's own: five folders and
# their declarations - gcp requires devops, python requires devops AND
# scaffold - the two invisible ones, in no list, travelling with what requires
# them. The folder names sort the list, so the boxes are gcp, python, vision.
$PacksRoot = New-PackRoot @(
    @{ Name = "gcp";      Description = "Google Cloud CLI";    Requires = "devops" },
    @{ Name = "vision";   Description = "Image and OCR tools" },
    @{ Name = "python";   Description = "Python toolchain";    Requires = "devops scaffold" },
    @{ Name = "devops";   Description = "Project targets";     Visible = "no" },
    @{ Name = "scaffold"; Description = "Project scaffolding"; Visible = "no" }
)
$Catalog = New-Catalog $PacksRoot

Write-Output "--- what the checkboxes mean ---"

# 1. An installed pack arrives checked; ticking one more box adds it - with what
#    it requires, and before it: gcp requires devops, and a pack is installed on
#    top of what it needs.
Check "one box ticked -> its requirement comes first, then it" `
    (($Catalog.ResolveSelection(@("gcp"), @("vision")) -join ",")) "devops,gcp"

# 2. Unticking what is installed, with nothing else ticked, is a removal - and
#    ONLY a removal.
Check "unticking -> the pack leaves, the rest is NOT added" `
    ((($Catalog.ResolveSelection(@(), @("vision")) -join ",")) + " / " + ($Catalog.ResolveRemoval(@("vision"), @("vision"), @()) -join ",")) " / vision"

# 3. Nothing checked and nothing installed is an ANSWER, not a cancellation:
#    the two lists come back empty and the caller decides what that means.
Check "an empty selection is empty, not a refusal" `
    (($Catalog.ResolveSelection(@(), @()).Count + $Catalog.ResolveRemoval(@(), @(), @()).Count)) 0

# 4. Two different facts. What the instance HAS is not what arrives ticked: at
#    build time the new instance has no pack yet (nothing can be removed), while
#    the ticked boxes are the ones its predecessor carried.
Check "pre-checked is not installed" `
    ((($Catalog.ResolveSelection(@("vision"), @()) -join ",")) + " / " + ($Catalog.ResolveRemoval(@(), @(), @()) -join ",")) "vision / "

# 5. A pack installed in the instance that THIS checkout does not carry is not
#    in the checklist, so nobody can have unchecked it - it must be left alone.
Check "a pack this checkout does not carry is left alone" `
    (($Catalog.ResolveRemoval(@("vision", "foreign"), @(), @()) -join ",")) ""

Write-Output ""
Write-Output "--- the packs nobody picks ---"

# 6. What the instance already carries is not installed a second time. devops is
#    there, python is ticked, and the requirement already in place is not copied
#    over itself - its install.sh does not run again. What is missing still
#    arrives, and before the pack that requires it.
Check "a requirement already installed is not installed again" `
    (($Catalog.ResolveSelection(@("python"), @("devops")) -join ",")) "scaffold,python"

# 7. An invisible pack has no box, so nobody can untick it - it leaves when the
#    last pack that requires it does, and in the same answer.
Check "the last claimant leaves -> the invisible ones go too" `
    (($Catalog.ResolveRemoval(@("python", "devops", "scaffold"), @("python"), @()) -join ",")) "python,devops,scaffold"

# 8. ... and one stays while an installed pack still requires it. That is the
#    whole reason they are not offered: another claimant is there to hold it.
Check "another claimant holds it -> it stays, and the other one goes" `
    (($Catalog.ResolveRemoval(@("python", "gcp", "devops", "scaffold"), @("python"), @()) -join ",")) "python,scaffold"

Write-Output ""
Write-Output "--- the refusal: a pack a standing pack requires does not leave ---"

# A second catalog of its own: a shape the first one does not carry - a
# VISIBLE pack that another visible one requires, which is what the guard is
# about.
$PacksRoot2 = New-PackRoot @(
    @{ Name = "oh_my_shell"; Description = "The shell" },
    @{ Name = "python";      Description = "Python toolchain"; Requires = "oh_my_shell" },
    @{ Name = "web";         Description = "Web tooling";      Requires = "oh_my_shell" }
)
$Guarded = New-Catalog $PacksRoot2

# The resolver reports what cannot leave, with the packs that hold it - and
# the two directions at once: a standing claimant holds, one leaving with it
# does not.
$Conflicts = @($Guarded.GetRemovalConflicts(@("oh_my_shell", "python"), @("oh_my_shell"), @()))
Check "a visible pack unticked under a standing claimant is a conflict" `
    ("$($Conflicts.Name)/$($Conflicts.Blockers -join ',')") "oh_my_shell/python"

$Conflicts = @($Guarded.GetRemovalConflicts(@("oh_my_shell", "python"), @("oh_my_shell", "python"), @()))
Check "both unticked -> both leave, nothing holds" ("$($Conflicts.Count)") "0"

$Conflicts = @($Guarded.GetRemovalConflicts(@("oh_my_shell"), @("oh_my_shell"), @("web")))
Check "a claimant just arriving holds it too" `
    ("$($Conflicts.Name)/$($Conflicts.Blockers -join ',')") "oh_my_shell/web"

# The rule under the guard: a visible pack is NEVER taken along by the
# cascade - only an invisible one leaves with the pack nothing requires any
# more. Both sides of that line, on the same departure.
Check "a visible pack is never cascaded out" `
    (($Guarded.ResolveRemoval(@("oh_my_shell", "python"), @("python"), @()) -join ",")) "python"
Check "  ... where an invisible one follows its last claimant" `
    (($Catalog.ResolveRemoval(@("python", "devops"), @("python"), @())) -join ",") "python,devops"

Write-Output ""
Write-Output "--- the family: a pack is only offered where its apt lives ---"

# A third catalog, of three packs of two families: the filter reads
# PACK_FAMILY (absent means debian), and the machine's own family decides
# which one a question shows.
$PacksRoot3 = New-PackRoot @(
    @{ Name = "alpha";      Description = "A Debian-family pack" },
    @{ Name = "beta";       Description = "A Fedora-family pack";   Family = "fedora" },
    @{ Name = "oh_my_shell"; Description = "A Fedora-family shell"; Family = "fedora" }
)
$Familied = New-Catalog $PacksRoot3

Check "a pack without PACK_FAMILY reads as debian" ($Familied.GetPack("alpha").Family) "debian"
Check "a declared family is read" ($Familied.GetPack("beta").Family) "fedora"
Check "the debian surface shows only the debian pack" `
    (($Familied.OfferedFor("debian").Name) -join ",") "alpha"
Check "  ... and the fedora one the other" `
    (($Familied.OfferedFor("fedora").Name) -join ",") "beta,oh_my_shell"
Check "a machine that cannot say filters nothing" `
    (($Familied.OfferedFor("").Name) -join ",") "alpha,beta,oh_my_shell"

Write-Output ""
Write-Output "--- the moves: the order, and where a failure stops ---"

# The catalog the moves read: fake-a and fake-b, nothing else.
$ApplyRoot = New-PackRoot @(
    @{ Name = "fake-a"; Description = "A fake pack" },
    @{ Name = "fake-b"; Description = "Another fake pack" }
)

function New-Service {
    param([FakeWsl]$Wsl)
    $instances = [InstanceRepository]::new((Join-Path ([System.IO.Path]::GetTempPath()) ("packs-select-world-" + [Guid]::NewGuid().ToString("N"))))
    New-Item -ItemType Directory -Path $instances.GetFolder("test") -Force | Out-Null
    $packs = [PackCatalogRepository]::new($ApplyRoot)
    return [InstanceService]::new($instances, $null, $Wsl, $null, $null, $packs, $null)
}

function New-Dto {
    param([string[]]$Add, [string[]]$Remove)
    $dto = [ManagePacksDto]::new()
    $dto.InstanceName = "test"
    $dto.ToAdd = @($Add)
    $dto.ToRemove = @($Remove)
    return $dto
}

$Directory = "/home/u/.config/packs"

# The newcomer is placed BEFORE a removal asks its question, its install runs
# BEFORE the removal, and the orphan cleanup travels LAST - the whole design
# of a shared package left where it is.
$Wsl = [FakeWsl]::new()
$Wsl.Installed = @("fake-b")
$Service = New-Service $Wsl
$Result = $Service.ManagePacks((New-Dto -Add @("fake-a") -Remove @("fake-b")))
$Calls = @($Wsl.Called)
Check "the newcomer is placed BEFORE the removal asks its question" `
    ($Calls.IndexOf("copy-to $Directory/fake-a") -lt $Calls.IndexOf("has $Directory/fake-b/remove.sh")) $true
Check "the install comes BEFORE the removal" `
    ($Calls.IndexOf("script $Directory/fake-a install.sh user") -lt $Calls.IndexOf("rm-folder $Directory/fake-b")) $true
Check "and the orphan cleanup is taken last" `
    ($Calls.IndexOf("rm-folder $Directory/fake-b") -lt $Calls.IndexOf("orphan-cleanup")) $true
Check "and the run is ok" "$($Result.Outcome)" "ok"
Check "  ... and the declared pair moved" "$(($Result.Installed -join ",") + "/" + ($Result.Removed -join ","))" "fake-a/fake-b"

# The door the installs run behind: opened before the install, closed after -
# and the root half runs BEFORE the door, where no door can open yet.
$Wsl = [FakeWsl]::new()
$Service = New-Service $Wsl
$null = $Service.ManagePacks((New-Dto -Add @("fake-a") -Remove @()))
$Calls = @($Wsl.Called)
Check "the door opens before the install" ($Calls.IndexOf("door-open") -lt $Calls.IndexOf("script $Directory/fake-a install.sh user")) $true
Check "and closes after it" ($Calls.IndexOf("script $Directory/fake-a install.sh user") -lt $Calls.IndexOf("door-close")) $true
Check "  ... and the root half ran before the door opened" `
    ($Calls.IndexOf("script $Directory/fake-a install_root.sh root") -lt $Calls.IndexOf("door-open")) $true
Check "nothing to remove -> no removal, and no orphan cleanup" (@($Calls | Where-Object { $_ -eq "orphan-cleanup" }).Count) 0

# A pack without a root half - claude is one - installs all the same.
$Wsl = [FakeWsl]::new()
$Wsl.HasRoot = $false
$Service = New-Service $Wsl
$null = $Service.ManagePacks((New-Dto -Add @("fake-a") -Remove @()))
$Calls = @($Wsl.Called)
Check "a pack without a root half skips it" (@($Calls | Where-Object { $_ -like "*install_root.sh root" }).Count) 0
Check "  ... and still runs its install behind the door" `
    ($Calls.IndexOf("script $Directory/fake-a install.sh user") -gt $Calls.IndexOf("door-open")) $true

# A root half that fails stops everything before the door: no install.sh has
# run, so the folder goes back out - and the door never opens.
$Wsl = [FakeWsl]::new()
$Wsl.FailScript = "install_root.sh"
$Service = New-Service $Wsl
$Result = $Service.ManagePacks((New-Dto -Add @("fake-a") -Remove @()))
$Calls = @($Wsl.Called)
Check "a failed root half names the pack" "$($Result.Failed)/$($Result.ExitCode)" "fake-a/1"
Check "  ... no install.sh ran" (@($Calls | Where-Object { $_ -like "* install.sh user" }).Count) 0
Check "  ... the door never opened" (@($Calls | Where-Object { $_ -eq "door-open" }).Count) 0
Check "  ... and the folder went back out" (@($Calls | Where-Object { $_ -eq "rm-folder $Directory/fake-a" }).Count) 1

# A removal without a remove.sh: the folder leaves, no script runs, and the
# cleanup travels all the same.
$Wsl = [FakeWsl]::new()
$Wsl.Installed = @("fake-b")
$Wsl.HasRemove = $false
$Service = New-Service $Wsl
$null = $Service.ManagePacks((New-Dto -Add @() -Remove @("fake-b")))
$Calls = @($Wsl.Called)
Check "no remove.sh -> the folder leaves, no script runs" `
    ("$(($Calls | Where-Object { $_ -like "* remove.sh *" }).Count)/$(($Calls | Where-Object { $_ -eq 'rm-folder /home/u/.config/packs/fake-b' }).Count)/$(($Calls | Where-Object { $_ -eq 'orphan-cleanup' }).Count)") "0/1/1"

# A failed copy names the pack that stopped it, and nothing else was touched.
$Wsl = [FakeWsl]::new()
$Wsl.Installed = @("fake-b")
$Wsl.FailScript = "copy"
$Service = New-Service $Wsl
$Result = $Service.ManagePacks((New-Dto -Add @("fake-a") -Remove @("fake-b")))
$Calls = @($Wsl.Called)
Check "a failed copy names the pack that stopped it" "$($Result.Failed)/$($Result.ExitCode)" "fake-a/1"
Check "  ... and nothing else was touched" (@($Calls | Where-Object { $_ -like "*fake-b*" }).Count) 0

# A failed install takes the folder back out - after the failure, not before.
$Wsl = [FakeWsl]::new()
$Wsl.FailScript = "install.sh"
$Service = New-Service $Wsl
$Result = $Service.ManagePacks((New-Dto -Add @("fake-a") -Remove @()))
$Calls = @($Wsl.Called)
Check "a failed install names the pack" "$($Result.Failed)/$($Result.ExitCode)" "fake-a/1"
Check "  ... and its folder goes back out, after the failure" `
    ($Calls.IndexOf("rm-folder $Directory/fake-a") -gt $Calls.IndexOf("script $Directory/fake-a install.sh user")) $true

# Exit code 2 is a pack that asked a question and was told no, not a failure:
# its folder goes back out, but the run carries on - no failure to explain.
$Wsl = [FakeWsl]::new()
$Wsl.FailScript = "install.sh"
$Wsl.FailCode = 2
$Service = New-Service $Wsl
$Result = $Service.ManagePacks((New-Dto -Add @("fake-a") -Remove @()))
$Calls = @($Wsl.Called)
Check "a declined install is not a failure" "$($Result.Outcome)/$(if (@($Result.Failed).Count -eq 0) { 'none' } else { $Result.Failed })" "ok/none"
Check "  ... and its folder goes back out" `
    ($Calls.IndexOf("rm-folder $Directory/fake-a") -gt $Calls.IndexOf("script $Directory/fake-a install.sh user")) $true

# A failed remove.sh names that pack - and the newcomer was already installed,
# the failure does not undo it, and both folders stay.
$Wsl = [FakeWsl]::new()
$Wsl.Installed = @("fake-b")
$Wsl.FailScript = "remove.sh"
$Service = New-Service $Wsl
$Result = $Service.ManagePacks((New-Dto -Add @("fake-a") -Remove @("fake-b")))
$Calls = @($Wsl.Called)
Check "a failed remove.sh names that pack" "$($Result.Failed)" "fake-b"
Check "  ... and the newcomer was already installed - the failure does not undo it" `
    (@($Calls | Where-Object { $_ -eq "script $Directory/fake-a install.sh user" }).Count) 1
Check "  ... and neither folder goes out" (@($Calls | Where-Object { $_ -like "rm-folder*" }).Count) 0

# A failure stops the queue at its pack: the ones after it were never
# touched - not even placed - so nothing of theirs is taken back, and the
# failing pack's own folder is the only one that goes out.
$Wsl = [FakeWsl]::new()
$Wsl.Installed = @("fake-b")
$Wsl.FailScript = "install.sh"
$Service = New-Service $Wsl
$Result = $Service.ManagePacks((New-Dto -Add @("fake-a", "fake-b") -Remove @("fake-b")))
$Calls = @($Wsl.Called)
Check "a failed install takes its own folder back out, and only it" `
    ((@($Calls | Where-Object { $_ -like "rm-folder*" }) -join " | ")) "rm-folder $Directory/fake-a"
Check "  ... and the pack after it never ran" `
    (@($Calls | Where-Object { $_ -eq "script $Directory/fake-b install.sh user" }).Count) 0
Check "  ... and the run names the pack that stopped it" "$($Result.Failed)/$($Result.ExitCode)" "fake-a/1"

# A copy that fails takes its own half-done folder back out; the pack before
# it is already installed and stays - a folder left behind, though, would
# pass for an installation.
$Wsl = [FakeWsl]::new()
$Wsl.FailScript = "copy"
$Wsl.FailAfter = 2
$Service = New-Service $Wsl
$Result = $Service.ManagePacks((New-Dto -Add @("fake-a", "fake-b") -Remove @()))
$Calls = @($Wsl.Called)
Check "a failed copy takes its own folder back out, nothing before it" `
    ((@($Calls | Where-Object { $_ -like "rm-folder*" }) -join " | ")) "rm-folder $Directory/fake-b"
Check "  ... and the run names the pack that stopped it" "$($Result.Failed)/$($Result.ExitCode)" "fake-b/1"

Remove-Item -Recurse -Force $PacksRoot, $PacksRoot2, $PacksRoot3, $ApplyRoot -ErrorAction SilentlyContinue

Write-Output ""
Write-Output ("failures: " + $Failures)
exit $Failures
