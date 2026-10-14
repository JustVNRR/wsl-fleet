# ==============================================================================
# ADDPACK — LA VUE WPF
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewWpf.psm1
using module ..\..\..\Dto\InstanceDto.psm1

# Un pack à ajouter : la liste des offrables, « Already in 'X' » dite au-dessus
# (l'ancienne le disait avant la liste, pas après), un choix, ADD. Rien à
# offrir : Ask rend $null — une réponse, pas une annulation.
class WpfAddPackView : BaseViewWpf {
    [object] Ask([object]$packs, [string]$name) {
        $self = $this
        $Installed = @($packs.Installed)
        $Candidates = @($packs.Candidate)
        if ($Candidates.Count -eq 0) { return $null }

        $this.Title = "Add a pack"
        $this.Width = 560
        $this.SizeToContent = [System.Windows.SizeToContent]::Height
        $this.MaxHeight = 760
        $this.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $this.ResizeMode = [System.Windows.ResizeMode]::NoResize
        $this.Load((Join-Path $PSScriptRoot "AddPack.xaml"))
        $this.WearDefault()
        $this.Dress($null, 15)

        $this.Find("TxtLead").Text = "Packs available for '$name':"
        $txtInstalled = $this.Find("TxtInstalled")
        if ($Installed.Count -gt 0) {
            $txtInstalled.Text = "Already in '$name': $($Installed -join ', ')"
            $txtInstalled.Visibility = [System.Windows.Visibility]::Visible
        }

        $lst = $this.Find("LstCandidates")
        foreach ($pack in $Candidates) {
            $null = $lst.Items.Add("{0,-12} {1}" -f $pack.Name, $pack.Description)
        }
        $lst.SelectedIndex = 0

        $this.Find("BtnPackCancel").Add_Click({ $self.Result = $null; $self.Close() })
        $this.Find("BtnPackAdd").Add_Click({
            $at = $lst.SelectedIndex
            if ($at -lt 0) { return }
            $dto = [AddPackDto]::new()
            $dto.InstanceName = $name
            $dto.PackName = "$($Candidates[$at].Name)"
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
