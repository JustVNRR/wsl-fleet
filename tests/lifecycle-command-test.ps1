# Drives the lifecycle commands - restart, shell, shrink, list - the way a
# script would: answers on standard input, no console anywhere, and a
# stand-in wsl.exe ahead on the PATH - built from tests\fake-wsl\wsl.cs,
# logging every call and answering from its own log: a distribution counts as
# running once a boot command has gone through.
#
# The instance it works on exists for the length of the test: a registry key
# of its own, a folder carrying the marker, and a name of its own - all under
# a working folder of the suite's, the one the commands will use: the
# redirected profile keeps the root file (root.txt) pointing there. The key is
# taken back out at the end. Nothing real is started or stopped: what is
# checked is the command emitted, its order, and what is said.
#
# The children are the entry itself, wsl.ps1, run with the command word - the
# same door a user's script goes through.
#
# What is checked: for `restart`, the stop comes before the boot; for
# `shell`, the session is asked by name; for `shrink`, the compact, and
# the restart only when it was running; for `list`, what the machine says -
# stopped or running, and an empty machine ending on one.
#
# It needs no instance, no console and no Docker Desktop.
#
# Usage:  pwsh -NoProfile -File tests\lifecycle-command-test.ps1
using module ..\src\windows\Service\ServiceFactory.psm1

$ErrorActionPreference = "Stop"

$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("lifecycle-command-test-" + [Guid]::NewGuid().ToString("N"))
$FakeName = "lifecycle-command-test"
$Key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss\{2f9f0a4e-58b1-4a3c-9d2e-0c1b2a3d4e5f}"
$Log = Join-Path $Tmp "wsl-calls.log"

# The world of the suite: the redirected profile, and the root file pointing
# under it - the working folder every run will use, the runs and this file
# alike.
$env:USERPROFILE = $Tmp
$env:LOCALAPPDATA = Join-Path $Tmp "LocalAppData"
$env:APPDATA = Join-Path $Tmp "AppData"
New-Item -ItemType Directory -Path (Join-Path $env:LOCALAPPDATA "wsl-stack") -Force | Out-Null
New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
Set-Content -Path (Join-Path $env:LOCALAPPDATA "wsl-stack\root.txt") -Value $Tmp -Encoding ascii
# L'instance vit ou le repertoire la cherche : sous la racine, par son nom.
$FakeFolder = Join-Path $Tmp $FakeName

# The entry, spelled the way a user's script spells it.
$Entry = Join-Path $PSScriptRoot "..\wsl.ps1"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Assets = Join-Path $RepoRoot "assets"
$distroTree = Join-Path $RepoRoot "src\distro"
if (-not (Test-Path $distroTree)) { $distroTree = "" }

# Child processes follow the engine this suite runs under, so a pass under 7
# tests the scripts under 7.
$Engine = if ($PSVersionTable.PSEdition -eq "Core") { "pwsh" } else { "powershell" }

# The stand-in, ahead of any wsl.exe for every child this suite starts: a real
# binary of that name, compiled here from tests\fake-wsl\wsl.cs - the scripts
# call `wsl.exe` with its extension, so only a binary answers to it, never a
# script. Its answers come from the log it writes: an empty log is a machine
# where nothing runs, a boot line makes the instance a running one.
$FakeDir = Join-Path $Tmp "fake-wsl"
New-Item -ItemType Directory -Path $FakeDir -Force | Out-Null
$Csc = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path $Csc)) { $Csc = Join-Path $env:WINDIR "Microsoft.NET\Framework\v4.0.30319\csc.exe" }
& $Csc /nologo /out:"$(Join-Path $FakeDir 'wsl.exe')" (Join-Path $PSScriptRoot "fake-wsl\wsl.cs")
if ($LASTEXITCODE -ne 0 -or -not (Test-Path (Join-Path $FakeDir "wsl.exe"))) {
    throw "the stand-in wsl.exe could not be compiled"
}
$env:PATH = $FakeDir + [IO.Path]::PathSeparator + $env:PATH
$env:FAKE_WSL_LOG = $Log
$env:FAKE_WSL_INSTANCE = $FakeName

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

# The child's own exit code, beside its output: a refusal is a result too.
$script:ChildExit = 0

# One command of the entry, in a fresh process - the answers on its standard
# input, as a script would feed them.
function Invoke-Child {
    param([string]$Word, [string[]]$Answers)

    $Preference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $Lines = $Answers | & $Engine -NoProfile -File $Entry $Word 2>&1
        $script:ChildExit = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $Preference
    }
    return $Lines
}

# What the stand-in was asked, in order - its log, line by line.
function Get-Calls {
    if (-not (Test-Path $Log)) { return @() }
    return @(Get-Content $Log | Where-Object { $_ })
}

New-Item -ItemType Directory -Path $FakeFolder -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $FakeFolder ".wsl-stack") -Force | Out-Null

try {
    Remove-Item $Key -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -Path $Key -Force | Out-Null
    Set-ItemProperty -Path $Key -Name DistributionName -Value $FakeName
    Set-ItemProperty -Path $Key -Name BasePath -Value $FakeFolder

    # Which number our instance is in the list the command draws - worked out
    # with the same code the entry builds, so the answer is right whatever
    # else is installed.
    $root = [ServiceFactory]::ResolveRoot($Assets, $distroTree)
    $service = [ServiceFactory]::CreateInstanceService($root, $Assets, $distroTree)
    $rows = @($service.GetAll() | Where-Object { -not $_.IsArchive })
    $Pick = [array]::IndexOf(@($rows.Name), $FakeName) + 1
    Check "the test's instance is in the list" ($Pick -ge 1) $true

    # 1. restart: the stop comes first, the boot after it, and the news last.
    # A boot in the log is what an earlier start would have left; the instance
    # is one of the running ones, so it is there to pick. The empty answer
    # takes the confirmation's default, which is yes.
    Remove-Item $Log -Force -ErrorAction SilentlyContinue
    Add-Content -Path $Log -Value "-d $FakeName --exec /bin/true"
    $Out = Invoke-Child -Word "restart" -Answers @("$Pick", "")
    $Calls = Get-Calls
    Check "restart stops the instance first" (@($Calls | Where-Object { $_ -eq "--terminate $FakeName" }).Count) 1
    Check "and boots it after the stop" `
        (([array]::IndexOf($Calls, "--terminate $FakeName")) -lt ([array]::LastIndexOf($Calls, "-d $FakeName --exec /bin/true"))) $true
    Check "and says it is running again" (@($Out | Where-Object { "$_".Contains("'$FakeName' is running again") }).Count -gt 0) $true
    Check "and ends on zero" $script:ChildExit 0

    # 2. shell: the session is asked of WSL by name, from the instance's home.
    # No WSL fragment is staged, so the bare console is the route. Nothing is
    # captured from the session: its code is handed back as it came.
    Remove-Item $Log -Force -ErrorAction SilentlyContinue
    $Out = Invoke-Child -Word "shell" -Answers @("$Pick")
    Check "shell opens a session on the instance picked" (@(Get-Calls | Where-Object { $_ -eq "-d $FakeName --cd ~" }).Count) 1
    # wsl.exe parses its own command line and does not strip quotes: a quoted
    # name stops matching (seen on a real machine - the same name unquoted
    # works). The joined arguments above cannot show that; the raw line can.
    Check "and the raw command line is on record" (@(Get-Calls | Where-Object { $_ -like "raw:*" }).Count -gt 0) $true
    Check "and the name reaches wsl unquoted" `
        (@(Get-Calls | Where-Object { $_ -like "raw:*" -and $_ -like "*`"$FakeName`"*" }).Count) 0
    Check "and says what it is doing" (@($Out | Where-Object { "$_".Contains("Opening a shell in '$FakeName'") }).Count -gt 0) $true
    Check "and hands the session's code over" $script:ChildExit 0

    # 3. shrink: one command, in place - and the instance comes back up only
    # if it was up. The archive question is answered no: a yes takes the
    # archive path, another suite's country.
    Remove-Item $Log -Force -ErrorAction SilentlyContinue
    $Out = Invoke-Child -Word "shrink" -Answers @("$Pick", "n")
    Check "shrink compacts the instance picked" (@(Get-Calls | Where-Object { $_ -eq "--manage $FakeName --compact" }).Count) 1
    Check "and says it is compacted" (@($Out | Where-Object { "$_".Contains("'$FakeName' compacted") }).Count -gt 0) $true
    Check "and a stopped one is not started" (@(Get-Calls | Where-Object { $_ -like "*--exec*" }).Count) 0
    Check "and ends on zero" $script:ChildExit 0

    Remove-Item $Log -Force -ErrorAction SilentlyContinue
    Add-Content -Path $Log -Value "-d $FakeName --exec /bin/true"
    $Out = Invoke-Child -Word "shrink" -Answers @("$Pick", "n")
    $Calls = Get-Calls
    Check "a running one is started again after the compact" `
        (([array]::IndexOf($Calls, "--manage $FakeName --compact")) -lt ([array]::LastIndexOf($Calls, "-d $FakeName --exec /bin/true"))) $true
    Check "and says it is running again" (@($Out | Where-Object { "$_".Contains("'$FakeName' is running again") }).Count -gt 0) $true

    # 4. list: the row says what the machine says, stopped or running - and an
    # empty machine is an answer with its own code, not a table over nothing.
    Remove-Item $Log -Force -ErrorAction SilentlyContinue
    $Out = Invoke-Child -Word "list" -Answers @("")
    Check "list shows the instance as stopped" `
        (@($Out | Where-Object { "$_" -match [regex]::Escape($FakeName) -and "$_" -match "stopped" }).Count -gt 0) $true
    Check "and ends on zero" $script:ChildExit 0

    Remove-Item $Log -Force -ErrorAction SilentlyContinue
    Add-Content -Path $Log -Value "-d $FakeName --exec /bin/true"
    $Out = Invoke-Child -Word "list" -Answers @("")
    Check "list shows a running one as running" `
        (@($Out | Where-Object { "$_" -match [regex]::Escape($FakeName) -and "$_" -match "running" }).Count -gt 0) $true

    Remove-Item $Key -Recurse -Force -ErrorAction SilentlyContinue
    $Out = Invoke-Child -Word "list" -Answers @("")
    Check "an empty machine is said, not printed over" `
        (@($Out | Where-Object { "$_".Contains("No instance of this template is registered") }).Count -gt 0) $true
    Check "and ends on one" $script:ChildExit 1
} finally {
    Remove-Item $Key -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
}

Write-Output ""
Write-Output ("failures: " + $Failures)

if ($Failures -gt 0) {
    Write-Output ""
    Write-Output "--- the last run's own words ---"
    foreach ($Line in @($Out)) { Write-Output "    | $Line" }
}
exit $Failures
