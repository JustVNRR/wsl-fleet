# The theme_font's conversation: the instance (asked here, or handed by the
# theme menu), the fragment warning, and the fonts asked again and again - one
# visit is any number of picks, Escape leaves. The picks travel whole, in
# order, and the command applies them: nothing is written here, so a visit
# abandoned at the end changes nothing.
using module ..\..\WslModel\WslModel.psd1

function Read-ThemeFontAnswers {
    param(
        [WslInstanceManager]$Manager,

        # The instance, when the theme menu has already asked which one: how
        # the level above hands over. Empty when the command is run on its
        # own, and the list is asked here.
        [string]$DistroName = "",

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
        Write-Host "        Run it on its own:  .\wsl.ps1 theme_font" -ForegroundColor (Get-MessageColour hint)
        return $null
    }

    # 1. Which instance - handed by the theme menu, or asked.
    $HandedOver = [bool]$DistroName
    if ($HandedOver) {
        $Distro = $Manager.FindByName($DistroName)
        if (-not $Distro) {
            Write-Host ""
            Write-Host "[ABORT] No instance named '$DistroName' is registered here." -ForegroundColor (Get-MessageColour error)
            return $null
        }
    } else {
        $Distro = Select-Distro -Manager $Manager
        $DistroName = $Distro.Name
    }

    # The menus it came through - the way in, the theme menu, the instance it
    # picked - come off the screen: this asks its own question now.
    Clear-MenuScreen

    # Worth saying before the question because it is what would make all of it
    # invisible: a font is only ever read through the fragment this repository
    # writes.
    $OurFragment = Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\wsl-stack\$DistroName.json"
    if (-not (Test-Path $OurFragment)) {
        Write-Host ""
        Write-Host "[WARNING] This instance has no Terminal profile of ours - the font would not show." -ForegroundColor (Get-MessageColour warning)
        Write-Host "          Build it again, or set the font by hand in Ctrl+," -ForegroundColor (Get-MessageColour muted)
    }

    # Every font Windows has that a terminal can use, with what it can draw -
    # read once for the whole visit.
    Write-Host ""
    Write-Host "Reading the fonts Windows has..." -ForegroundColor (Get-MessageColour muted)
    $Fonts = @(Get-UsableFonts)

    # 2. The list, again and again. The font in use is the profile's - or the
    # last pick, since nothing is applied before the visit is over; each pick
    # joins the ones before it, and the command replays them in order.
    $Picks = @()
    $Default = 0
    while ($true) {
        $Current = if ($Picks.Count -gt 0) { $Picks[-1] } else { $Manager.AppearanceOf($Distro).FontName }

        # The one in use stays in the list, and the mark rides the row: the
        # label reads nothing from around itself.
        $Rows = @(Get-FontChoices -Fonts $Fonts -Current $Current | ForEach-Object {
            @{ Name = $_.Name; Current = ($_.Name -eq $Current) }
        })

        $Picked = Select-FromList -Title "Font of '$DistroName'" -Items $Rows -Label {
            param($Font)
            $Here = if ($Font.Current) { "(current)" } else { "" }
            "{0,-33} {1}" -f $Font.Name, $Here
        } -DefaultIndex $Default -Note "Get more Nerd Fonts at https://www.nerdfonts.com"

        if (-not $Picked) { break }

        # The menu has been answered: the screen goes clean, and the answer
        # takes its place - then the screen again, so the list comes back on
        # its own.
        Clear-MenuScreen

        # The same place next time.
        $Default = [array]::IndexOf(@($Rows | ForEach-Object { $_.Name }), $Picked.Name)
        $Picks += $Picked.Name

        Clear-MenuScreen
    }

    Clear-MenuScreen

    # Nothing picked and the visit over: handed over, the level above owns the
    # goodbye; on its own, cancelling is said once.
    if ($Picks.Count -eq 0) {
        if ($HandedOver) { return $null }
        Stop-Cancelled
    }

    return [PSCustomObject]@{ Instance = $Distro; Fonts = @($Picks) }
}
