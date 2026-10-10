# The manage_packs' conversation: the picker, the guards and the checklist,
# fed by the command line's own words - none - and renders the answers
# object the command works from. The command holds the making.
using module ..\..\WslModel\WslModel.psd1

function Read-ManagePacksAnswers {
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
        Write-Host "        Run it on its own:  .\wsl.ps1 manage_packs" -ForegroundColor (Get-MessageColour hint)
        return $null
    }

    # 1. Which instance. The checklist runs inside it, so it has to be up.
    $Distro = Select-Distro -Manager $Manager
    if (-not $Distro) { Stop-Cancelled }
    $DistroName = $Distro.Name
    Invoke-External { wsl.exe -d $DistroName --exec /bin/true } "Could not start '$DistroName'."

    # 2. Every pack this checkout carries, and what that instance already has
    $Catalog = $Manager.Catalog
    if ($Catalog.AvailablePacks.Count -eq 0) {
        Write-Host ""
        Write-Host "[ABORT] No pack found in $($Catalog.PacksRoot)." -ForegroundColor (Get-MessageColour error)
        Write-Host "        A pack is a folder there carrying a pack.conf." -ForegroundColor (Get-MessageColour hint)
        return $null
    }

    $Installed = $Manager.InstalledPacks($Distro)
    if ($null -eq $Installed) {
        Write-Host ""
        Write-Host "[ABORT] '$DistroName' did not say where its user's home is." -ForegroundColor (Get-MessageColour error)
        return $null
    }

    # 3. The checklist, and what it says to do. The family it filters with is
    # asked of the engine.
    $Selection = Select-Packs -Title "Packs for '$DistroName'" -Catalog $Catalog -Installed @($Installed) -Family $Manager.FamilyOf($Distro)

    if ($null -eq $Selection) { Stop-Cancelled }
    if ($Selection.ToAdd.Count -eq 0 -and $Selection.ToRemove.Count -eq 0) {
        Write-Host ""
        Write-Host "[OK] Nothing to do: '$DistroName' already has exactly that." -ForegroundColor (Get-MessageColour success)
        exit 0
    }

    return [PSCustomObject]@{
        Instance = $Distro
        ToAdd    = @($Selection.ToAdd)
        ToRemove = @($Selection.ToRemove)
    }
}
