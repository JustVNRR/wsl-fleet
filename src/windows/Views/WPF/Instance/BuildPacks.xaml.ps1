using module ..\BaseViewWpf.psm1

class WpfBuildPacksView : BaseViewWpf {

    [object] Ask([string]$name, [string]$family, [object[]]$packs) {
        $self = $this
        $this.Title = "Packs for the build"
        $this.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
        $this.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $this.ResizeMode = [System.Windows.ResizeMode]::NoResize
        $this.Load((Join-Path $PSScriptRoot "BuildPacks.xaml"))
        $this.WearDefault()
        $this.Dress($null, 15)

        $this.Find("TxtPacksTitle").Text = "ADD PACKS FOR '$name'"

        if (-not $family) { $this.Find("TxtPacksForeign").Visibility = [System.Windows.Visibility]::Visible }

        $offered = if ($family) { @($packs | Where-Object { $_.Family -eq $family }) } else { @($packs) }
        $panel = $this.Find("Boxes")
        $entries = @()
        foreach ($pack in $offered) {
            $check = New-Object System.Windows.Controls.CheckBox
            $label = New-Object System.Windows.Controls.TextBlock
            $label.TextWrapping = [System.Windows.TextWrapping]::Wrap
            $label.Text = "{0,-12} [{1}] {2}" -f $pack.Name, $pack.Family, $pack.Description
            $check.Content = $label
            $check.Margin = "0,3,0,3"
            $check.IsChecked = [bool]($family -and $pack.Shell -and $pack.Family -eq $family)
            $entries += [PSCustomObject]@{ Pack = $pack; Check = $check }
            $null = $panel.Children.Add($check)
        }

        $txtNotes = $this.Find("TxtNotes")
        $Refresh = {
            $ticked = @($entries | Where-Object { $_.Check.IsChecked })
            $txtNotes.Text = if ($ticked.Count -eq 0) { "No pack selected - it will start bare." } else { "" }
        }
        foreach ($entry in $entries) {
            $entry.Check.Add_Checked({ & $Refresh })
            $entry.Check.Add_Unchecked({ & $Refresh })
        }
        & $Refresh

        $this.Find("BtnPickCancel").Add_Click({ $self.Close() })
        $this.Find("BtnPickApply").Add_Click({
            $names = @($entries | Where-Object { $_.Check.IsChecked } | ForEach-Object { "$($_.Pack.Name)" })
            $self.Result = @($names)
            $self.Close()
        })

        $this.FitToContent($null)
        $null = $this.OpenAs($null)
        if ($null -eq $this.Result) { return $null }
        return [PSCustomObject]@{ Packs = [string[]]@($this.Result) }
    }
}
