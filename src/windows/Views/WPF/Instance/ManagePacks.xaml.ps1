# ==============================================================================
# MANAGEPACKS — LA VUE WPF
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewWpf.psm1
using module ..\..\..\Dto\InstanceDto.psm1

# La checklist du service, en fenêtre : une case par ligne — les offrables
# décochées, les portables cochées —, et sous elles les deux lignes du
# cli (Will install / Will remove), calculées du même écart :
# cochée et pas portée entre, portée et décochée sort. Les requirements,
# les invisibles et les refus se résolvent au service, à l'application.
# Rien à faire : Ask rend $null (une réponse, pas une annulation).
class WpfManagePacksView : BaseViewWpf {
    [object] Ask([object]$packs, [string]$name) {
        $self = $this
        $Installed = @($packs.Installed)

        # Les lignes : les offrables (décochées) puis les portables (cochées).
        $rows = @()
        $checked = @{}
        foreach ($pack in @($packs.Candidate)) {
            $rows += [PSCustomObject]@{ Name = "$($pack.Name)"; Description = "$($pack.Description)" }
        }
        foreach ($removable in @($packs.Removable)) {
            if (@($rows | Where-Object { $_.Name -eq "$removable" }).Count -gt 0) { continue }
            $rows += [PSCustomObject]@{ Name = "$removable"; Description = "" }
            $checked["$removable"] = $true
        }
        if ($rows.Count -eq 0) { return $null }

        $this.Title = "Packs"
        $this.Width = 560
        $this.SizeToContent = [System.Windows.SizeToContent]::Height
        $this.MaxHeight = 760
        $this.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $this.ResizeMode = [System.Windows.ResizeMode]::NoResize
        $this.Load((Join-Path $PSScriptRoot "ManagePacks.xaml"))
        $this.WearDefault()
        $this.Dress($null, 15)

        $this.Find("TxtLead").Text = "Packs for '$name'"
        $this.Find("TxtNothing").Text = "'$name' carries nothing to choose and this repository offers nothing to add."

        # Une case par ligne — l'étiquette plie au lieu de filer hors de la
        # fenêtre (une chaîne nue refuse de plier, mesuré).
        $panel = $this.Find("PnlPacks")
        $entries = @()
        foreach ($row in $rows) {
            $check = New-Object System.Windows.Controls.CheckBox
            $label = New-Object System.Windows.Controls.TextBlock
            $label.TextWrapping = [System.Windows.TextWrapping]::Wrap
            $label.Text = "{0,-12} {1}" -f $row.Name, $row.Description
            $check.Content = $label
            $check.Margin = "0,3,0,3"
            $check.IsChecked = [bool]$checked[$row.Name]
            $entries += [PSCustomObject]@{ Row = $row; Check = $check }
            $null = $panel.Children.Add($check)
        }

        $txtWillAdd = $this.Find("TxtWillAdd")
        $txtWillRemove = $this.Find("TxtWillRemove")
        $btnApply = $this.Find("BtnPacksApply")
        $Refresh = {
            $ticked = @($entries | Where-Object { $_.Check.IsChecked } | ForEach-Object { $_.Row.Name })
            $toAdd = @($ticked | Where-Object { $Installed -notcontains $_ })
            $toRemove = @($packs.Removable | Where-Object { $ticked -notcontains $_ })

            $txtWillAdd.Text = if ($toAdd.Count -gt 0) { "Will install : $($toAdd -join ', ')" } else { "" }
            $txtWillAdd.Visibility = if ($txtWillAdd.Text) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
            $txtWillRemove.Text = if ($toRemove.Count -gt 0) { "Will remove  : $($toRemove -join ', ')" } else { "" }
            $txtWillRemove.Visibility = if ($txtWillRemove.Text) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
            $btnApply.IsEnabled = ($toAdd.Count -gt 0 -or $toRemove.Count -gt 0)
        }
        foreach ($entry in $entries) {
            $entry.Check.Add_Checked({ & $Refresh })
            $entry.Check.Add_Unchecked({ & $Refresh })
        }
        & $Refresh

        $this.Find("BtnPacksCancel").Add_Click({ $self.Result = $null; $self.Close() })
        $btnApply.Add_Click({
            $ticked = @($entries | Where-Object { $_.Check.IsChecked } | ForEach-Object { $_.Row.Name })
            $dto = [ManagePacksDto]::new()
            $dto.InstanceName = $name
            $dto.ToAdd = @($ticked | Where-Object { $Installed -notcontains $_ })
            $dto.ToRemove = @($packs.Removable | Where-Object { $ticked -notcontains $_ })
            if ($dto.ToAdd.Count -eq 0 -and $dto.ToRemove.Count -eq 0) { return }
            $self.Result = $dto
            $self.Close()
        })

        $this.FitToContent($null)
        $null = $this.OpenAs($null)
        return $this.Result
    }

    # Le rapport — la ligne d'état de la fenêtre principale le porte.
    [void] Show([string]$name, [object]$response) {
    }
}
