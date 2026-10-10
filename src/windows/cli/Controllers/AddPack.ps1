# The add_pack's conversation: the pickers - the instance, then the pack -
# and their guards, fed by the command line's own words - none - and renders
# the answers object the command works from. The command holds the making.
using module ..\..\WslModel\WslModel.psd1

function Read-AddPackAnswers {
    param(
        [WslInstanceManager]$Manager,

        # What was typed after the command, untouched. The vocabulary is
        # empty: any word stops the run before a single question.
        [object[]]$Options = @()
    )

    # The words, paired up - the same reading the other conversations do:
    # a glued '-Name:value' is taken whole, and a word with no dash is kept
    # as an option named itself, so it lands in the refusal.
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
        Write-Host "        Run it on its own:  .\wsl.ps1 add_pack" -ForegroundColor (Get-MessageColour hint)
        return $null
    }

    # 1. Which instance the pack goes into. The copy and the install happen
    # inside it, so it has to be up.
    $Distro = Select-Distro -Manager $Manager
    $DistroName = $Distro.Name
    Invoke-External { wsl.exe -d $DistroName --exec /bin/true } "Could not start '$DistroName'."

    # 2. Which pack - the ones this repository carries and that instance
    # lacks.
    $Catalog = $Manager.Catalog
    if ($Catalog.AvailablePacks.Count -eq 0) {
        Write-Host ""
        Write-Host "[ABORT] No pack found in $($Catalog.PacksRoot)." -ForegroundColor (Get-MessageColour error)
        Write-Host "        A pack is a folder there carrying a pack.conf." -ForegroundColor (Get-MessageColour hint)
        return $null
    }

    # The engine provides what that instance carries ($null when its home
    # cannot be named) and the ones a question may offer: an invisible pack
    # arrives with the pack that requires it, never offered.
    $Installed = $Manager.InstalledPacks($Distro)
    if ($null -eq $Installed) {
        Write-Host ""
        Write-Host "[ABORT] '$DistroName' did not say where its user's home is." -ForegroundColor (Get-MessageColour error)
        return $null
    }

    $Candidates = @($Manager.CandidatePacks($Distro))
    if ($Candidates.Count -eq 0) {
        Write-Host ""
        Write-Host "[OK] '$DistroName' already has every pack this repository offers." -ForegroundColor (Get-MessageColour success)
        exit 0
    }

    # Said before the list, not after it: with the arrows the rows are drawn
    # in place, and anything under them gets painted over.
    if (@($Installed).Count -gt 0) {
        Write-Host ""
        Write-Host ("       Already in '$DistroName': {0}" -f (@($Installed) -join ", ")) -ForegroundColor (Get-MessageColour muted)
    }

    $Pack = Select-FromList -Title "Packs available for '$DistroName':" -Items $Candidates -Label {
        param($Entry)
        "{0,-12} {1}" -f $Entry.Name, $Entry.Description
    }

    if (-not $Pack) { Stop-Cancelled }

    return [PSCustomObject]@{
        Instance = $Distro
        Pack     = $Pack.Name
    }
}
