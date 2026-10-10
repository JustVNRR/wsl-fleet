# The restore's conversation, out of the command file: the console asks
# everything here - the archive, the name of the new instance, and the Docker
# word when it is due - fed by the command line's own words, read here and
# nowhere else, and renders the answers object the command works from. The
# command holds the making: nothing past this returns asks anything.
using module ..\..\WslModel\WslModel.psd1

function Read-RestoreAnswers {
    param(
        [WslInstanceManager]$Manager,

        # What was typed after the command, untouched. The vocabulary is
        # empty: restore answers nothing in advance, and any word stops the
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
        Write-Host "        Run it on its own:  .\wsl.ps1 restore" -ForegroundColor (Get-MessageColour hint)
        return $null
    }

    # 1. What there is to restore from. An empty folder is not an error to
    # work around: it says how to fill it. Nothing to pick, nothing asked.
    $ArchiveFolder = $Manager.ArchivesRoot
    if (-not (Test-Path $ArchiveFolder)) {
        Write-Host ""
        Write-Host "[ABORT] There are no archives: $ArchiveFolder does not exist." -ForegroundColor (Get-MessageColour error)
        Write-Host "        Nothing to restore:" -ForegroundColor (Get-MessageColour hint)
        Write-Host "            - Create one with  .\wsl.ps1 archive" -ForegroundColor (Get-MessageColour hint)
        Write-Host "            - Or move the existing ones back into $ArchiveFolder" -ForegroundColor (Get-MessageColour hint)
        return $null
    }

    # An archive is an instance at rest - the tar it holds, and the look it
    # was taken with. The engine's own rows, most recent first, usually the
    # one wanted back.
    $Archives = @($Manager.List().Archives)

    if ($Archives.Count -eq 0) {
        Write-Host ""
        Write-Host "[ABORT] The archives folder is empty: $ArchiveFolder" -ForegroundColor (Get-MessageColour error)
        Write-Host "        Nothing to restore:" -ForegroundColor (Get-MessageColour hint)
        Write-Host "            - Create one with  .\wsl.ps1 archive" -ForegroundColor (Get-MessageColour hint)
        Write-Host "            - Or move the existing ones back into $ArchiveFolder" -ForegroundColor (Get-MessageColour hint)
        return $null
    }

    # 2. Pick one: nothing cancels, as everywhere else.
    $Chosen = Select-FromList -Title "Archives in $ArchiveFolder (most recent first):" -Items $Archives -Label {
        param($Entry)
        "{0}  -  {1}, {2}" -f $Entry.Name, (Format-Size $Entry.DiskBytes()),
            $Entry.ArchivedOn().ToString("yyyy-MM-dd HH:mm")
    }

    if (-not $Chosen) { Stop-Cancelled -What "created" }

    # 3. Name the new instance
    Write-Host ""
    Write-Host "Restoring $($Chosen.Name) as a new instance." -ForegroundColor (Get-MessageColour info)
    $Name = [string](Read-Host "Name of the new instance (Enter to cancel)")
    if ([string]::IsNullOrWhiteSpace($Name)) { Stop-Cancelled -What "created" }
    $Name = $Name.Trim()

    # 4. Docker Desktop: the archive may carry an instance Docker knew, and
    # the new name is not in its list - adding the name restarts Docker, so
    # the [y/N] is the user's. The engine answers whether the question is due
    # at all; the answer rides into the making. Nothing else is checked
    # here: the model's own doors refuse a name that cannot be (taken, a
    # folder in the way), and the refusal comes back.
    $Carried = $Manager.ArchiveDocker($Chosen.ArchivePath)
    $AddDocker = $false
    if ($Manager.DockerQuestionDue($Carried, $Name)) {
        Write-Host ""
        if (Confirm-YesNo "Add '$Name' to Docker Desktop? (it restarts Docker)" -DefaultNo) { $AddDocker = $true }
    }

    return [PSCustomObject]@{
        Instance  = $Chosen
        Name      = $Name
        AddDocker = $AddDocker
    }
}
