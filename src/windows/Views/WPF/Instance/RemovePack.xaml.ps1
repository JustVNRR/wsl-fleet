# ==============================================================================
# REMOVEPACK — LA VUE WPF
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewWpf.psm1
using module ..\..\..\Dto\InstanceDto.psm1

# Un pack à retirer : la liste des portables, le choix, et la question d'avant
# — « Remove 'X'? » — qui suit la sélection ; REMOVE est rouge, comme toute
# destruction. Rien de portable : Ask rend $null.
class WpfRemovePackView : BaseViewWpf {
    [object] Ask([object]$packs, [string]$name) {
        $self = $this
        $Offered = @($packs.Removable)
        if ($Offered.Count -eq 0) { return $null }

        $this.Title = "Remove a pack"
        $this.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
        $this.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $this.ResizeMode = [System.Windows.ResizeMode]::NoResize
        $this.Load((Join-Path $PSScriptRoot "RemovePack.xaml"))
        $this.WearDefault()
        $this.Dress($null, 15)

        $this.Find("TxtLead").Text = "Packs installed in '$name':"
        $lst = $this.Find("LstPacks")
        foreach ($packName in $Offered) { $null = $lst.Items.Add("$packName") }
        $lst.SelectedIndex = 0

        $txtQuestion = $this.Find("TxtQuestion")
        $lst.Add_SelectionChanged({
            $at = $lst.SelectedIndex
            $txtQuestion.Text = if ($at -ge 0) { "Remove '$($Offered[$at])'?" } else { "" }
        })
        $at = $lst.SelectedIndex
        $txtQuestion.Text = if ($at -ge 0) { "Remove '$($Offered[$at])'?" } else { "" }

        $this.Find("BtnPackCancel").Add_Click({ $self.Result = $null; $self.Close() })
        $this.Find("BtnPackRemove").Add_Click({
            $at = $lst.SelectedIndex
            if ($at -lt 0) { return }
            $dto = [RemovePackDto]::new()
            $dto.InstanceName = $name
            $dto.PackName = "$($Offered[$at])"
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
