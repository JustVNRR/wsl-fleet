# The remove_pack's conversation: the picker and the confirmation, fed by the
# command line's own words - none - and renders the answers object the
# command works from. The command holds the making.
using module ..\..\WslModel\WslModel.psd1

function Read-RemovePackAnswers {
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
        Write-Host "        Run it on its own:  .\wsl.ps1 remove_pack" -ForegroundColor (Get-MessageColour hint)
        return $null
    }

    # 1. Which instance the pack comes out of
    $Distro = Select-Distro -Manager $Manager
    $DistroName = $Distro.Name

    # The pack's files are read inside it, so it has to be up.
    Invoke-External { wsl.exe -d $DistroName --exec /bin/true } "Could not start '$DistroName'."

    # 2. Which pack - the ones a user chooses. A pack marked invisible in its
    # own pack.conf is not offered: it leaves with the last pack that
    # requires it. No guard on an empty catalog: a pack installed from
    # another checkout is still a pack this command can take out.
    $Installed = $Manager.InstalledPacks($Distro)
    if ($null -eq $Installed) {
        Write-Host ""
        Write-Host "[ABORT] '$DistroName' did not say where its user's home is." -ForegroundColor (Get-MessageColour error)
        return $null
    }
    if (@($Installed).Count -eq 0) {
        Write-Host ""
        Write-Host "[OK] '$DistroName' carries no pack - there is nothing to remove." -ForegroundColor (Get-MessageColour success)
        exit 0
    }

    $Offered = @($Manager.RemovablePacks($Distro))
    if ($Offered.Count -eq 0) {
        Write-Host ""
        Write-Host "[OK] '$DistroName' carries no pack you choose or remove by hand." -ForegroundColor (Get-MessageColour success)
        exit 0
    }

    $PackName = Select-FromList -Title "Packs installed in '$DistroName':" -Items $Offered

    if (-not $PackName) { Stop-Cancelled }

    # 3. The one question. What leaves with the pack is the engine's rule,
    # said after the fact.
    Write-Host ""
    if (-not (Confirm-YesNo "Remove '$PackName'?")) { Stop-Cancelled }

    return [PSCustomObject]@{
        Instance = $Distro
        Pack     = $PackName
    }
}
