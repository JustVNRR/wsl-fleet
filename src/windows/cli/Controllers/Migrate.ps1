# The migrate's conversation, out of the command file: the console asks
# everything here - the folder the fleet goes to, given with -Target or asked
# - fed by the command line's own words, read here and nowhere else, and
# renders the answers object the command works from. The folder is made
# ready here, before anything is archived: a target that cannot exist stops
# the run with nothing done. The command holds the making.
using module ..\..\WslModel\WslModel.psd1

function Read-MigrateAnswers {
    param(
        [WslInstanceManager]$Manager,

        # What was typed after the command, untouched. The vocabulary is
        # -Target: it answers the folder question in advance, and any other
        # word stops the run before a single question.
        [object[]]$Options = @()
    )

    # The words, paired up - the same reading the build's and the archive's
    # conversations do: a splatted pair arrives as '-Name:' followed by its
    # value (measured), a glued '-Name:value' is taken whole, and a word
    # with no dash is kept as an option named itself, so it lands in the
    # refusal like a stranger.
    $Typed = @{}
    $Pending = ""
    foreach ($Word in @($Options)) {
        $Word = "$Word"
        if ($Word.StartsWith('-')) {
            $Rest = $Word.TrimStart('-')
            $Cut = $Rest.IndexOf(':')
            if ($Cut -ge 0) {
                $Pending = $Rest.Substring(0, $Cut)
                $Glued = $Rest.Substring($Cut + 1)
                if ($Glued) { $Typed[$Pending] = $Glued; $Pending = "" }
                elseif (-not $Typed.ContainsKey($Pending)) { $Typed[$Pending] = "" }
            } else {
                $Pending = $Rest
                if (-not $Typed.ContainsKey($Pending)) { $Typed[$Pending] = "" }
            }
            continue
        }
        if ($Pending) { $Typed[$Pending] = $Word; $Pending = "" }
        else { $Typed[$Word] = "" }
    }
    foreach ($Option in @($Typed.Keys)) {
        if ($Option -notin @("Target")) {
            Write-Host ""
            Write-Host "[ABORT] Unknown options after the command." -ForegroundColor (Get-MessageColour error)
            Write-Host "        Run it on its own:  .\wsl.ps1 migrate" -ForegroundColor (Get-MessageColour hint)
            return $null
        }
    }

    $SourceBase = $Manager.InstancesRoot

    # 1. The folder to go to: given, or asked. Nothing to move is a no-op,
    # not a run.
    $Target = if ($Typed.ContainsKey("Target")) { "$($Typed.Target)" } else { Read-Answer -Question "Move the fleet from '$SourceBase' to" -What "moved" }
    $Target = $Target.Trim().Trim('"').TrimEnd('\')
    if ($Target -eq $SourceBase.TrimEnd('\')) {
        Write-Host ""
        Write-Host "  That is the working folder - nothing to move." -ForegroundColor (Get-MessageColour warning)
        exit 0
    }

    # The folder is made ready here - before anything is archived, so a
    # target that cannot exist stops the run with nothing done. An existing
    # folder is fine: nothing of it is erased, and its own `archives` is
    # refused later, by the engine's voyage.
    try {
        $null = New-Item -ItemType Directory -Path $Target -Force -ErrorAction Stop
    } catch {
        Write-Host ""
        Write-Host "[ABORT] '$Target' cannot be used: $($_.Exception.Message)" -ForegroundColor (Get-MessageColour error)
        return $null
    }

    return [PSCustomObject]@{ Target = $Target }
}
