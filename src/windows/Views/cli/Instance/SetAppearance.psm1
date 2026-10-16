using module ..\BaseViewCli.psm1

class CliSetAppearanceView : BaseViewCli {

    [void] ShowNoFragmentWarning() {
        Write-Host ""
        Write-Host "[WARNING] This instance has no Terminal profile of ours - the look would not show." -ForegroundColor $this.Colour("warning")
        Write-Host "          Build it again, or set it by hand in Ctrl+," -ForegroundColor $this.Colour("muted")
    }

    [string] AskTheme([string]$name) {
        $choices = @(
            @{ What = "icon";  About = "the tile in the tab" },
            @{ What = "font";  About = "what the whole terminal is written in" },
            @{ What = "color"; About = "the background, the text, and sixteen colours" }
        )
        $chosen = $this.AskList("Theme of '$name'", $choices, { param($choice) "{0,-6} {1}" -f $choice.What, $choice.About }, "")
        if ($null -eq $chosen) { return "" }
        return "$($chosen.What)"
    }

    [string] AskFont([string]$name, [string[]]$fonts, [string]$current) {
        $rows = @($fonts | ForEach-Object {
            $here = if ($_ -eq $current) { "(current)" } else { "" }
            [PSCustomObject]@{ Name = "$_"; Text = "{0,-33} {1}" -f "$_", $here }
        })
        $picked = $this.AskList("Font of '$name'", $rows, { param($row) $row.Text }, "Get more Nerd Fonts at https://www.nerdfonts.com")
        if ($null -eq $picked) { return "" }
        return "$($picked.Name)"
    }

    [string] AskColour([string]$name, [object[]]$schemes, [string]$current) {
        $escape = [char]27
        $coloured = $this.ColourOutput()
        $rows = @($schemes | Sort-Object Name | ForEach-Object {
            $scheme = $_
            $here = if ($scheme.Name -eq $current) { "(current)" } else { "" }
            $text = "{0,-20} {1,-11}" -f $scheme.Name, $here
            if ($here -and $coloured) {
                $text = $text -replace [regex]::Escape($here), ("{0}[91m{1}{0}[39m" -f $escape, $here)
            }
            $sample = $text
            if ($coloured -and $scheme.Background -and $scheme.Foreground) {
                $sample = "{0}[0m{0}[48;2;{1}m{0}[38;2;{2}m{3}{0}[0m" -f $escape, $this.Rgb($scheme.Background), $this.Rgb($scheme.Foreground), $text
            }
            [PSCustomObject]@{ Name = "$($scheme.Name)"; Text = $sample }
        })
        $picked = $this.AskList("Colours of '$name'", $rows, { param($row) $row.Text }, "")
        if ($null -eq $picked) { return "" }
        return "$($picked.Name)"
    }

    [string] AskIconType([string]$name) {
        $choices = @(
            @{ What = "By Default"; How = "auto" },
            @{ What = "text";       How = "letters" },
            @{ What = "colors";     How = "colours" },
            @{ What = "local file"; How = "image" }
        )
        $chosen = $this.AskList("Icon of '$name'", $choices, { param($choice) $choice.What }, "")
        if ($null -eq $chosen) { return "" }
        return "$($chosen.How)"
    }

    [object] AskLetters([string]$question) {
        Write-Host -NoNewline "${question}: "
        $answer = $this.AskLine("")
        if ($null -eq $answer) { return $null }
        return "$answer".Trim()
    }

    [void] ShowLettersHint() {
        Write-Host "  One to three letters or digits." -ForegroundColor $this.Colour("hint")
    }

    [object] AskIconPair([string]$name, [object[]]$pairs, [string]$suggestion, [string]$currentTop, [string]$currentBottom) {
        $escape = [char]27
        $coloured = $this.ColourOutput()
        $rows = @($pairs | ForEach-Object {
            $pair = $_
            $sample = $suggestion
            if ($coloured -and $suggestion) {
                $ink = if ($pair.TextColor -eq "#FFFFFF") { "97" } else { "30" }
                $sample = "{0}[48;2;{1}m{0}[{2}m {3} {0}[0m" -f $escape, $this.Rgb($pair.Top), $ink, $suggestion
            }
            $here = if ($pair.Top -eq $currentTop -and $pair.Bottom -eq $currentBottom) { "  (current)" } else { "" }
            [PSCustomObject]@{ Pair = $pair; Text = "{0}  {1,-9}{2}" -f $sample, $pair.Name, $here }
        })
        $picked = $this.AskList("Colours for '$name'", $rows, { param($row) $row.Text }, "")
        if ($null -eq $picked) { return "" }
        return $picked.Pair
    }

    [object] AskImagePath() {
        $answer = $this.AskLine("Path of the image, PNG JPG ICO or BMP (CTRL+C to abort)")
        if ($null -eq $answer) { return $null }
        return "$answer".Trim('"')
    }

    [void] ShowNoFile() {
        Write-Host "  No file at that path." -ForegroundColor $this.Colour("warning")
    }

    [void] ShowBadExtension() {
        Write-Host "  The name has to end in .png, .jpg, .jpeg, .ico or .bmp." -ForegroundColor $this.Colour("hint")
    }

    [void] Show([object]$response) {
        Write-Host ""
        Write-Host "==> Theme of '$($response.InstanceName)': $(@($response.Changes) -join ', ')" -ForegroundColor $this.Colour("success")
        Write-Host ""
    }
}
