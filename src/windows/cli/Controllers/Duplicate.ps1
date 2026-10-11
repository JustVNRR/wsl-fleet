# The duplicate's conversation, out of the command file: the console asks
# everything here - the source, the copy's name, the stopping when it runs,
# and the Docker word when it is due - fed by the command line's own words,
# read here and nowhere else, and renders the answers object the command
# works from. The command holds the making: nothing past this returns asks
# anything.
using module ..\..\WslModel\WslModel.psd1

function Read-DuplicateAnswers {
    param(
        [WslInstanceManager]$Manager,

        # What was typed after the command, untouched. The vocabulary is
        # empty: duplicate answers nothing in advance, and any word stops the
        # run before a single question.
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
        Write-Host ""
        Write-Host "[ABORT] Unknown options after the command." -ForegroundColor (Get-MessageColour error)
        Write-Host "        Run it on its own:  .\wsl.ps1 duplicate" -ForegroundColor (Get-MessageColour hint)
        return $null
    }

    # 1. Which instance to copy. Ours only: the list vouches for them.
    $Source = Select-Distro -Manager $Manager

    # 2. The copy's name: typed, because there is nothing to pick from. The
    # question comes back until the name is usable; a taken one is the
    # engine's refusal to make, not a question here.
    $NewDistroName = Read-InstanceName "Name of the copy" -What "created"

    # 3. The export stops the source - WSL terminates it to read a consistent
    # disk - and unsaved work is gone: ask rather than surprise. The yes is
    # the word the engine's own copy acts on: the instance stops itself for
    # the export and comes back up when the stopping was ours to do.
    if ((Get-DistroNames -Running) -contains $Source.Name) {
        Write-Host ""
        Write-Host "  '$($Source.Name)' is running, and this needs it stopped." -ForegroundColor (Get-MessageColour warning)
        Write-Host "  Save what you have open in there: stopping it loses anything unsaved." -ForegroundColor (Get-MessageColour warning)
        if (-not (Confirm-YesNo "Stop it now?")) { Stop-Cancelled }
    }

    # 4. Docker Desktop: adding the copy's name restarts Docker, so the [y/N]
    # is the user's - the engine answers whether the question is due, and the
    # answer rides into the copy. Nothing else is checked here: the model's
    # own doors refuse a name that cannot be (taken, a folder in the way),
    # and the refusal comes back.
    $Carried = $Manager.DockerStateOf($Source)
    $AddDocker = $false
    if ($Manager.DockerQuestionDue($Carried, $NewDistroName)) {
        Write-Host ""
        if (Confirm-YesNo "Add '$NewDistroName' to Docker Desktop? (it restarts Docker)" -DefaultNo) { $AddDocker = $true }
    }

    return [PSCustomObject]@{
        Instance  = $Source
        Name      = $NewDistroName
        AddDocker = $AddDocker
    }
}
