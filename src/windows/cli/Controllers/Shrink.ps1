# The shrink's conversation, out of the command file: the console asks
# everything here - which instance, and the safety copy's question - fed by
# the command line's own words, read here and nowhere else, and renders the
# answers object the command works from. The command holds the making:
# nothing past this returns asks anything.
using module ..\..\WslModel\WslModel.psd1

function Read-ShrinkAnswers {
    param(
        [WslInstanceManager]$Manager,

        # What was typed after the command, untouched. The vocabulary is
        # empty: shrink answers nothing in advance, and any word stops the
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
        Write-Host "        Run it on its own:  .\wsl.ps1 shrink" -ForegroundColor (Get-MessageColour hint)
        return $null
    }

    # 1. Which instance. The list is the only way in.
    $Distro = Select-Distro -Manager $Manager
    if (-not $Distro) { Stop-Cancelled }
    $DistroName = $Distro.Name

    # 2. A copy first, yes by default: compacting rewrites the disk's
    # metadata - exactly what a backup a minute before turns into a
    # non-event. Typing an existing name is how an archive is replaced -
    # said, not done quietly - and the engine answers whether one exists.
    Write-Host ""
    $ArchiveFirst = Confirm-YesNo "Archive it first?"
    if (-not $ArchiveFirst) {
        Write-Host "  No archive - compacting on its own." -ForegroundColor (Get-MessageColour muted)
    } elseif ($Manager.HasArchive($DistroName)) {
        Write-Host "  '$DistroName' exists: replacing its archive." -ForegroundColor (Get-MessageColour warning)
    }

    return [PSCustomObject]@{
        Instance     = $Distro
        ArchiveFirst = [bool]$ArchiveFirst
    }
}
