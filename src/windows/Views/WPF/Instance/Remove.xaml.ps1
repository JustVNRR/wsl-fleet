# ==============================================================================
# REMOVE — LA VUE WPF
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewWpf.psm1
using module ..\..\..\Dto\InstanceDto.psm1

# La porte de la destruction, la même fenêtre qu'aujourd'hui : la phrase avec
# le nom, l'écho de ce qui part, la case « archiver d'abord », et le nom exact
# retapé — le bouton ne s'éveille que sur lui, casse comprise (le -ceq de la
# console). Entrée est REMOVE, Échap est Cancel : le XAML les porte. Ask rend
# le RemoveDto complet ; le rapport, lui, reviendra avec la fenêtre principale
# (sa ligne d'état).
class WpfRemoveView : BaseViewWpf {
    [object] Ask([string]$name, [object[]]$rows) {
        $self = $this
        $this.Title = "Remove instance"
        $this.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
        $this.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $this.ResizeMode = [System.Windows.ResizeMode]::NoResize
        $this.Load((Join-Path $PSScriptRoot "Remove.xaml"))
        $this.WearDefault()
        $this.Dress($null, 15)

        $this.Find("TxtLead").Text = "The WSL distribution '$name' and ALL its data will be deleted."

        $txtName = $this.Find("TxtName")
        $btnRemove = $this.Find("BtnGateRemove")
        $chkArchive = $this.Find("ChkArchive")
        $null = $chkArchive.Focus()

        $txtName.Add_TextChanged({
            # -ceq : le nom exact, casse comprise.
            $btnRemove.IsEnabled = ($txtName.Text -ceq $name)
        })
        $this.Find("BtnGateCancel").Add_Click({ $self.Result = $null; $self.Close() })
        $btnRemove.Add_Click({
            $dto = [RemoveDto]::new()
            $dto.InstanceName = $name
            $dto.ArchiveFirst = [bool]$chkArchive.IsChecked
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
