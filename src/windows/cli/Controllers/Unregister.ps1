# The unregister's conversation, out of the command file: the console asks
# everything here - which instance, the typed-name gate that says the
# destruction is meant, and the archive-before question - fed by the command
# line's own words, read here and nowhere else, and renders the answers
# object the command works from. The command holds the making: nothing past
# this returns asks anything.
using module ..\..\WslModel\WslModel.psd1

function Read-UnregisterAnswers {
    param(
        [WslInstanceManager]$Manager,

        # What was typed after the command, untouched. The vocabulary is
        # empty: unregister answers nothing in advance, and any word stops
        # the run before a single question.
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
        Write-Host "        Run it on its own:  .\wsl.ps1 unregister" -ForegroundColor (Get-MessageColour hint)
        return $null
    }

    # 1. Which distro, from the list, always. A folder left behind by an
    # earlier removal is deleted by hand, not by naming it here.
    $Ours = @($Manager.WslRegisteredInstances())
    if ($Ours.Count -eq 0) {
        Write-Host ""
        Write-Host "[ABORT] No instance of this template is registered on this machine." -ForegroundColor (Get-MessageColour error)
        Write-Host "        Nothing to remove." -ForegroundColor (Get-MessageColour hint)
        Write-Host "        Build one with  .\wsl.ps1 build" -ForegroundColor (Get-MessageColour hint)
        Write-Host "        (A folder left behind by an earlier removal is deleted by hand: $($Manager.InstancesRoot))" -ForegroundColor (Get-MessageColour muted)
        return $null
    }

    $Distro = Select-Distro -Manager $Manager
    if (-not $Distro) { Stop-Cancelled }
    $DistroName = $Distro.Name

    # 2. The confirmation (destructive) - the gate build asks too, written
    # once. A wrong name, or the empty answer, cancels the whole run.
    if (-not (Confirm-Destruction -DistroName $DistroName -Lead "The WSL distribution '$DistroName' and ALL its data will be deleted:")) {
        Write-Host "[ABORT] Operation cancelled. No data was modified." -ForegroundColor (Get-MessageColour warning)
        exit 0
    }

    # 3. The last moment to take a copy, and the manager's act on the word:
    # the copy first, the destruction after.
    Write-Host ""
    $ArchiveFirst = Confirm-YesNo "Archive it before deleting?" -DefaultNo

    # The same name is replaced without a word, otherwise - said, not quiet.
    # The engine answers whether an archive of that name exists.
    if ($ArchiveFirst) {
        if ($Manager.HasArchive($DistroName)) {
            Write-Host "  '$DistroName' exists: replacing its archive." -ForegroundColor (Get-MessageColour warning)
        }
    }

    return [PSCustomObject]@{
        Instance     = $Distro
        ArchiveFirst = [bool]$ArchiveFirst
    }
}
