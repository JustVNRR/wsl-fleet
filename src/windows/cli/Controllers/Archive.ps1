# The archive's conversation, out of the command file: the console asks
# everything here - the instance, the stopping when it runs, the archive's
# name, and whether the instance is kept - fed by the command line's own
# words, read here and nowhere else, and renders the answers object the
# command works from. The command holds the making: nothing past this
# returns asks anything.
using module ..\..\WslModel\WslModel.psd1

function Read-ArchiveAnswers {
    param(
        [WslInstanceManager]$Manager,

        # What was typed after the command, untouched. The vocabulary lives
        # here: -Format answers its question in advance; anything else stops
        # the run before a single question.
        [object[]]$Options = @()
    )

    # The words, paired up - the same reading the build's conversation does:
    # a splatted pair arrives as '-Name:' followed by its value (measured),
    # a glued '-Name:value' is taken whole, and a word with no dash is kept
    # as an option named itself, so it lands in the refusal like a stranger.
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
        if ($Option -notin @("Format")) {
            Write-Host ""
            Write-Host "[ABORT] Unknown options after the command." -ForegroundColor (Get-MessageColour error)
            Write-Host "        Run it on its own:  .\wsl.ps1 archive" -ForegroundColor (Get-MessageColour hint)
            return $null
        }
    }
    $Format = if ($Typed.ContainsKey("Format")) { "$($Typed.Format)" } else { "tar.gz" }
    if ($Format -notin @("tar", "tar.gz", "tar.xz")) {
        Write-Host ""
        Write-Host "[ABORT] '$Format' is not a format: tar, tar.gz or tar.xz." -ForegroundColor (Get-MessageColour error)
        Write-Host "        Nothing was modified." -ForegroundColor (Get-MessageColour muted)
        return $null
    }

    # 1. Which instance. Ours only: the list vouches for them.
    $Distro = Select-Distro -Manager $Manager

    # 2. The export stops the instance - WSL terminates it to read a
    # consistent disk - and unsaved work is gone: ask rather than surprise.
    # The yes is the permit the instance's own Archive receives; a no stops
    # the whole run, nothing asked further.
    $Permit = $true
    if ((Get-DistroNames -Running) -contains $Distro.Name) {
        Write-Host ""
        Write-Host "  '$($Distro.Name)' is running, and this needs it stopped." -ForegroundColor (Get-MessageColour warning)
        Write-Host "  Save what you have open in there: stopping it loses anything unsaved." -ForegroundColor (Get-MessageColour warning)
        if (-not (Confirm-YesNo "Stop it now?")) { Stop-Cancelled }
    }

    # 3. The name. An archive is a folder: the tar AND the look - an icon and
    # a colour scheme are Windows settings, not a tar's. The instance's name
    # is proposed, a taken name gets the next free suffix, and typing an
    # existing name is how an archive is replaced.
    $ArchiveFolder = $Manager.ArchivesRoot
    # The free name comes from the engine - it knows its archives - and the
    # rows below are its own, in their names' order here.
    $Proposal = $Manager.ProposeArchiveName($Distro.Name)

    $Existing = @($Manager.List().Archives | Sort-Object Name)
    Write-Host ""
    if ($Existing.Count -eq 0) {
        Write-Host "No archive yet in $ArchiveFolder." -ForegroundColor (Get-MessageColour muted)
    } else {
        Write-Host "Archives already in ${ArchiveFolder}:" -ForegroundColor (Get-MessageColour info)
        foreach ($Entry in $Existing) {
            Write-Host ("  {0,-30} {1,10}  {2}" -f $Entry.Name, (Format-Size $Entry.DiskBytes()),
                $Entry.ArchivedOn().ToString("yyyy-MM-dd HH:mm")) -ForegroundColor (Get-MessageColour muted)
        }
    }
    Write-Host ""
    $Answer = [string](Read-Host "Name of the archive? [$Proposal]")
    $Chosen = if ([string]::IsNullOrWhiteSpace($Answer)) { $Proposal } else { $Answer.Trim() }

    if ($Chosen -match '[\\/]') {
        Write-Host ""
        Write-Host "[ABORT] '$Chosen' is a path. Give a name - it lands in:" -ForegroundColor (Get-MessageColour error)
        Write-Host "        $ArchiveFolder" -ForegroundColor (Get-MessageColour hint)
        Write-Host "        Nothing was modified." -ForegroundColor (Get-MessageColour muted)
        return $null
    }

    # 4. What becomes of the instance, asked now: kept - the default - or
    # removed once the archive is on disk. The removal asks again there: the
    # typed name is what this repository asks before destroying anything.
    $Keep = Confirm-YesNo "Keep '$($Distro.Name)' once the archive is written?"

    return [PSCustomObject]@{
        Instance = $Distro
        Name     = $Chosen
        Format   = $Format
        Permit   = $Permit
        Delete   = (-not $Keep)
    }
}
