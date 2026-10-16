using module .\MenuCli.psm1
using module .\ThemeCli.psm1

class BaseViewCli {
    BaseViewCli() {}

    [object] Colour([string]$tone) {
        return [ThemeCli]::GetColor($tone)
    }

    [void] ClearScreen() {
        try { Clear-Host } catch { }
    }

    [bool] KeyInput() {
        if ([Console]::IsInputRedirected) { return $false }
        try {
            $console = Get-Variable -Name Host -ValueOnly
            $null = $console.UI.RawUI.KeyAvailable
            return $true
        } catch {
            return $false
        }
    }

    [string] Rgb([string]$hex) {
        $Hex = $hex.TrimStart("#")
        return "{0};{1};{2}" -f [Convert]::ToInt32($Hex.Substring(0, 2), 16),
                               [Convert]::ToInt32($Hex.Substring(2, 2), 16),
                               [Convert]::ToInt32($Hex.Substring(4, 2), 16)
    }

    [bool] ColourOutput() {
        if ($env:NO_COLOR) { return $false }
        if ([Console]::IsOutputRedirected) { return $false }
        return $true
    }

    [object] AskList([string]$title, [object[]]$items, [scriptblock]$label, [string]$note) {
        $Items = @($items)
        if ($Items.Count -eq 0) { return $null }

        $Menu = [MenuCli]::new($title)
        $Menu.Note = $note
        foreach ($Item in $Items) {
            $null = $Menu.Add([MenuItemCli]::new([string](& $label $Item), $Item))
        }
        $Picked = $Menu.Prompt()

        if ($null -eq $Picked) { return $null }
        return $Picked.Value
    }

    [object[]] AskChecklist([string]$title, [object[]]$items, [scriptblock]$label, [int[]]$checkedIndexes, [string]$note) {
        $Items = @($items)
        if ($Items.Count -eq 0) { return @() }

        $Menu = [MenuCli]::new($title)
        foreach ($Item in $Items) {
            $null = $Menu.Add([MenuItemCli]::new([string](& $label $Item), $Item))
        }
        $Menu.Multi = $true
        $Menu.Note = $note
        foreach ($Index in @($checkedIndexes)) {
            if ($Index -ge 0 -and $Index -lt $Menu.Items.Count) { $Menu.Items[$Index].Checked = $true }
        }
        $Picked = $Menu.Prompt()

        if ($null -eq $Picked) { return $null }
        return @($Picked | ForEach-Object { $_.Value })
    }

    [bool] Confirm([string]$question, [bool]$defaultNo) {
        $Shown = if ($defaultNo) { "$question [y/N]" } else { "$question [Y/n]" }
        $Answer = [string](Read-Host $Shown)
        if ($defaultNo) { return ($Answer -match "^[yY]") }
        return ($Answer -notmatch "^[nN]")
    }

    [void] ShowDangerBanner([string]$message) {
        $Colours = [ThemeCli]::GetBannerColors()

        Write-Host " /!\ ================================================================ /!\" -ForegroundColor $Colours.Ink -BackgroundColor $Colours.Box
        Write-Host (" |   {0,-60} |" -f $message) -ForegroundColor $Colours.Ink -BackgroundColor $Colours.Box
        Write-Host " \!/ ================================================================ \!/" -ForegroundColor $Colours.Ink -BackgroundColor $Colours.Box
    }

    [void] ShowCancelled([string]$what) {
        Write-Host ""
        Write-Host "[ABORT] Operation cancelled by user. Nothing was $what." -ForegroundColor $this.Colour("success")
    }
}
