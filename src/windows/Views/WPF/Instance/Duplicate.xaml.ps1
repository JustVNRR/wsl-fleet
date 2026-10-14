# ==============================================================================
# DUPLICATE — LA VUE WPF
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewWpf.psm1
using module ..\..\..\Dto\InstanceDto.psm1

# La copie, la même fenêtre qu'aujourd'hui : la phrase, l'avertissement
# d'arrêt (la liste ne porte plus l'état — il se dit toujours, comme au cli),
# le nom de la copie — celui de la source prérempli avec « -copy » derrière —
# et la vérification vivante du nom : vide, la forme, c'est tout. Le nom pris,
# lui, n'est pas su ici : le moteur refuse pour de vrai quand la course part,
# et le rapport le dira — la boîte avertit, elle ne verrouille pas.
# Entrée est DUPLICATE, Échap est Cancel.
class WpfDuplicateView : BaseViewWpf {
    [object] Ask([string]$source) {
        $self = $this
        $this.Title = "Duplicate"
        $this.Width = 540
        $this.SizeToContent = [System.Windows.SizeToContent]::Height
        $this.MaxHeight = 760
        $this.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $this.ResizeMode = [System.Windows.ResizeMode]::NoResize
        $this.Load((Join-Path $PSScriptRoot "Duplicate.xaml"))
        $this.WearDefault()
        $this.Dress($null, 15)

        $this.Find("TxtLead").Text = "Copy '$source'."
        $txtName = $this.Find("TxtName")
        $txtNameError = $this.Find("TxtNameError")
        $txtName.Text = "$source-copy"

        $this.Add_ContentRendered({ $null = $txtName.Focus(); $txtName.SelectAll() })

        # La règle des noms d'instance, la même partout : la forme vérifiée en
        # direct sous la boîte.
        $CheckName = {
            $name = "$($txtName.Text)".Trim()
            $problem = ""
            if (-not $name) { $problem = "Give a name." }
            elseif ($name -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*$') { $problem = "Letters, digits, '.', '_' and '-' only." }
            $txtNameError.Text = $problem
            $txtNameError.Visibility = if ($problem) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
        }
        $txtName.Add_TextChanged({ & $CheckName })
        & $CheckName

        $this.Find("BtnDupCancel").Add_Click({ $self.Result = $null; $self.Close() })
        $this.Find("BtnDupGo").Add_Click({
            & $CheckName
            $name = "$($txtName.Text)".Trim()
            if (-not $name) { return }
            $dto = [DuplicateDto]::new()
            $dto.SourceName = $source
            $dto.CopyName = $name
            $self.Result = $dto
            $self.Close()
        })

        $this.FitToContent($null)
        $null = $this.OpenAs($null)
        return $this.Result
    }

    # Le rapport — la ligne d'état de la fenêtre principale le porte.
    [void] Show([string]$source, [object]$response) {
    }
}
