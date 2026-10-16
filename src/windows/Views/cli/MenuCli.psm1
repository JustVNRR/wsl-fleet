using module .\ThemeCli.psm1

class MenuItemCli {
    [string]$Key
    [string]$Text
    [object]$Value
    [bool]$Checked = $false
    [scriptblock]$Action

    MenuItemCli([string]$Key, [string]$Description, [scriptblock]$Action) {
        $this.Key    = $Key
        $this.Text   = "{0,-12} {1}" -f $Key, $Description
        $this.Action = $Action
    }

    MenuItemCli([string]$Text, [object]$Value) {
        $this.Text  = $Text
        $this.Value = $Value
    }

}

class ConsoleCli {
    [bool] HasKeyboard() {
        if ([Console]::IsInputRedirected) { return $false }
        try {
            $null = (Get-Variable -Name Host -ValueOnly).UI.RawUI.KeyAvailable
            return $true
        } catch {
            return $false
        }
    }

    [ConsoleKey] ReadKey() {
        return [Console]::ReadKey($true).Key
    }

    [object] Top() {
        try { return [Console]::CursorTop } catch { return $null }
    }

    [bool] SetTop([int]$Top) {
        try {
            [Console]::SetCursorPosition(0, $Top)
            return ([Console]::CursorTop -eq $Top)
        } catch {
            return $false
        }
    }

    [int[]] Size() {
        try {
            $Size = (Get-Variable -Name Host -ValueOnly).UI.RawUI.WindowSize
            return @([int]$Size.Width, [int]$Size.Height)
        } catch {
            return @(0, 0)
        }
    }

    [void] Line([string]$Text, [string]$Kind) {
        if ($Kind) {
            Write-Host $Text -ForegroundColor ([ThemeCli]::GetColor($Kind))
        } else {
            Write-Host $Text
        }
    }

    [string] Prompt([string]$Prompt) {
        return [string](Read-Host $Prompt)
    }
}

class MenuCli {
    [string]$Title
    [ConsoleCli]$Console
    [System.Collections.Generic.List[MenuItemCli]]$Items
    [bool]$Multi = $false
    [int]$Current = 0
    [string]$Note = ""

    MenuCli([string]$Title) {
        $this.Title   = $Title
        $this.Console = [ConsoleCli]::new()
        $this.Items   = [System.Collections.Generic.List[MenuItemCli]]::new()
    }

    [MenuCli] Add([MenuItemCli]$Row) {
        $this.Items.Add($Row)
        return $this
    }

    [MenuCli] Add([string]$Key, [string]$Description, [scriptblock]$Action) {
        return $this.Add([MenuItemCli]::new($Key, $Description, $Action))
    }

    [MenuItemCli] Dispatch([string]$Key) {
        $Wanted = "$Key".ToLower()
        foreach ($Command in $this.Items) {
            if ($Command.Key -eq $Wanted) { return $Command }
        }
        return $null
    }

    [object] Prompt() {
        if ($this.Items.Count -eq 0) { return $null }
        if ($this.Console.HasKeyboard()) {
            return $this.PromptArrows()
        }
        return $this.PromptNumbers()
    }

    static [string] FormatRow([int]$Index, [int]$Current, [string[]]$Labels, [bool[]]$Checked) {
        $Marker = if ($Index -eq $Current) { "  > " } else { "    " }
        if ($null -eq $Checked) { return ($Marker + $Labels[$Index]) }
        $Box = if ($Checked[$Index]) { "[x] " } else { "[ ] " }
        return ($Marker + $Box + $Labels[$Index])
    }

    static [string[]] Fit([string[]]$Labels, [int]$Width, [int]$Prefix) {
        if ($Width -le 0) { return $Labels }
        $Room = $Width - 1
        return @($Labels | ForEach-Object {
            $Max = $Room - $Prefix
            if ($_.Length -le $Max) { $_ }
            else { $_.Substring(0, [Math]::Max(1, $Max - 3)) + "..." }
        })
    }

    hidden [object] Flags() {
        if (-not $this.Multi) { return $null }
        return @($this.Items | ForEach-Object { $_.Checked })
    }

    hidden [void] DrawRow([int]$Index, [string[]]$Texts) {
        $Kind = if ($Index -eq $this.Current) { "info" } else { "" }
        $this.Console.Line([MenuCli]::FormatRow($Index, $this.Current, $Texts, $this.Flags()), $Kind)
    }

    hidden [object] PromptArrows() {
        $Count = $this.Items.Count
        if ($this.Current -lt 0 -or $this.Current -ge $Count) { $this.Current = 0 }

        $Texts = @($this.Items | ForEach-Object { $_.Text })
        $Hint = if ($this.Multi) { "  up/down to move, space to check, Enter to apply, Escape to cancel" }
                else { "  up/down to move, Enter to choose, Escape to cancel" }
        $Size = $this.Console.Size()
        $Extra = if ($this.Note) { 1 } else { 0 }
        $Shown = [MenuCli]::Fit($Texts, $Size[0], $(if ($this.Multi) { 8 } else { 4 }))
        $ShownTitle = @([MenuCli]::Fit(@($this.Title), $Size[0], 0))[0]
        $ShownHint = @([MenuCli]::Fit(@($Hint), $Size[0], 0))[0]
        $ShownNote = @([MenuCli]::Fit(@($this.Note), $Size[0], 0))[0]

        $Visible = if ($Size[1] -gt 0) { [Math]::Min($Count, [Math]::Max(1, $Size[1] - 3 - $Extra)) } else { $Count }
        $First = [Math]::Max(0, [Math]::Min($this.Current - [int](($Visible - 1) / 2), $Count - $Visible))

        $this.Console.Line("", "")
        if ($ShownTitle) { $this.Console.Line($ShownTitle, "info") }
        for ($Row = 0; $Row -lt $Visible; $Row++) { $this.DrawRow($First + $Row, $Shown) }
        $this.Console.Line($ShownHint, "muted")
        if ($ShownNote) { $this.Console.Line($ShownNote, "muted") }

        $Cursor = $this.Console.Top()
        $Top = if ($null -ne $Cursor) { $Cursor - ($Visible + 1 + $Extra) } else { 0 }
        $CanPaint = ($null -ne $Cursor) -and ($Top -ge 0)

        while ($true) {
            $Key = $this.Console.ReadKey()
            $Last = $Count - 1
            $Moved = $true

            if ($Key -eq [ConsoleKey]::UpArrow) {
                $this.Current = if ($this.Current -eq 0) { $Last } else { $this.Current - 1 }
            } elseif ($Key -eq [ConsoleKey]::DownArrow) {
                $this.Current = if ($this.Current -eq $Last) { 0 } else { $this.Current + 1 }
            } elseif ($Key -eq [ConsoleKey]::Spacebar -and $this.Multi) {
                $this.Items[$this.Current].Checked = -not $this.Items[$this.Current].Checked
            } elseif ($Key -eq [ConsoleKey]::Enter) {
                if ($CanPaint) { $null = $this.Console.SetTop($Top + $Visible + 1 + $Extra) }
                if ($this.Multi) {
                    return @($this.Items | Where-Object { $_.Checked })
                }
                return $this.Items[$this.Current]
            } elseif ($Key -eq [ConsoleKey]::Escape) {
                if ($CanPaint) { $null = $this.Console.SetTop($Top + $Visible + 1 + $Extra) }
                return $null
            } elseif (($Key -ge [ConsoleKey]::D1 -and $Key -le [ConsoleKey]::D9) -or
                      ($Key -ge [ConsoleKey]::NumPad1 -and $Key -le [ConsoleKey]::NumPad9)) {
                $Wanted = if ($Key -ge [ConsoleKey]::NumPad1) { [int]$Key - [int][ConsoleKey]::NumPad1 }
                          else { [int]$Key - [int][ConsoleKey]::D1 }
                if ($Wanted -lt $Count) {
                    if ($this.Multi) {
                        $this.Items[$Wanted].Checked = -not $this.Items[$Wanted].Checked
                    } else {
                        if ($CanPaint) { $null = $this.Console.SetTop($Top + $Visible + 1 + $Extra) }
                        return $this.Items[$Wanted]
                    }
                }
            } else {
                $Moved = $false
            }

            if (-not $Moved -or -not $CanPaint) { continue }

            if ($this.Current -lt $First) { $First = $this.Current }
            if ($this.Current -ge ($First + $Visible)) { $First = $this.Current - $Visible + 1 }

            $Placed = $true
            for ($Row = 0; $Row -lt $Visible; $Row++) {
                if (-not $this.Console.SetTop($Top + $Row)) { $Placed = $false; break }
                $this.DrawRow($First + $Row, $Shown)
            }
            if (-not $Placed) {
                for ($Row = 0; $Row -lt $Visible; $Row++) { $this.DrawRow($First + $Row, $Shown) }
            }
        }

        return $null
    }

    hidden [object] PromptNumbers() {
        $Count = $this.Items.Count
        $Texts = @($this.Items | ForEach-Object { $_.Text })

        if ($this.Multi) {
            while ($true) {
                $this.Console.Line("", "")
                if ($this.Title) { $this.Console.Line($this.Title, "info") }
                for ($Index = 0; $Index -lt $Count; $Index++) {
                    $Box = if ($this.Items[$Index].Checked) { "[x]" } else { "[ ]" }
                    $this.Console.Line(("  {0,2}.  {1} {2}" -f ($Index + 1), $Box, $Texts[$Index]), "")
                }
                $this.Console.Line("   0.  Cancel", "")
                if ($this.Note) { $this.Console.Line("  $($this.Note)", "muted") }

                $Answer = $this.Console.Prompt("Number toggles, v applies, 0 cancels")
                if ([string]::IsNullOrWhiteSpace($Answer) -or $Answer.Trim() -eq "0") { return $null }
                if ($Answer.Trim() -match "^[vV]$") {
                    return @($this.Items | Where-Object { $_.Checked })
                }
                $Number = 0
                if ([int]::TryParse($Answer.Trim(), [ref]$Number) -and
                    $Number -ge 1 -and $Number -le $Count) {
                    $this.Items[$Number - 1].Checked = -not $this.Items[$Number - 1].Checked
                    continue
                }
                $this.Console.Line("  '$Answer' is not one of the numbers above.", "warning")
            }
        }

        $this.Console.Line("", "")
        if ($this.Title) { $this.Console.Line($this.Title, "info") }
        for ($Index = 0; $Index -lt $Count; $Index++) {
            $this.Console.Line(("  {0,2}.  {1}" -f ($Index + 1), $Texts[$Index]), "")
        }
        $this.Console.Line("   0.  Cancel", "")
        if ($this.Note) { $this.Console.Line("  $($this.Note)", "muted") }

        while ($true) {
            $Answer = $this.Console.Prompt("Which one? (0 to cancel)")
            if ([string]::IsNullOrWhiteSpace($Answer)) { return $null }
            $Number = 0
            if ([int]::TryParse($Answer.Trim(), [ref]$Number)) {
                if ($Number -eq 0) { return $null }
                if ($Number -ge 1 -and $Number -le $Count) { return $this.Items[$Number - 1] }
            }
            $this.Console.Line("  '$Answer' is not one of the numbers above.", "warning")
        }

        return $null
    }
}
