# The restart's conversation: the picker and the confirmation, fed by the
# command line's own words - none - and renders the answers object the
# command works from. The command holds the making.
using module ..\..\WslModel\WslModel.psd1

function Read-RestartAnswers {
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
        Write-Host "        Run it on its own:  .\wsl.ps1 restart" -ForegroundColor (Get-MessageColour hint)
        return $null
    }

    # 1. Who can be restarted: our running instances, and only those.
    $Distro = Select-EligibleInstance -Manager $Manager -State Running `
        -Title "Running instances - the ones that can be restarted:" `
        -None "No instance is running." -Nothing "Nothing to restart."

    # 2. A restart is a stop with a start behind it; the stop can lose
    # unsaved work. Asked once, default yes.
    Write-Host ""
    Write-Host "  '$($Distro.Name)' will be stopped, then started again." -ForegroundColor (Get-MessageColour warning)
    Write-Host "  Whatever is open in there and not saved is lost; what is already" -ForegroundColor (Get-MessageColour warning)
    Write-Host "  written on the disk stays exactly as it is." -ForegroundColor (Get-MessageColour warning)
    if (-not (Confirm-YesNo "Restart it?")) { Stop-Cancelled }

    return [PSCustomObject]@{ Instance = $Distro }
}
