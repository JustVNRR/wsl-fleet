# ==============================================================================
# RESTORE — LA VUE WPF
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewWpf.psm1
using module ..\..\..\Dto\InstanceDto.psm1

# La restauration, la même fenêtre qu'aujourd'hui : la phrase avec l'archive,
# et le nom que la nouvelle instance prend — l'archive préremplie, la ramener
# sous son nom étant la réponse usuelle. La boîte prend le focus une fois la
# fenêtre montée, son texte sélectionné : tapé droit, il répond le nom voulu
# (posé avant l'affichage, le focus et la sélection ne tiennent pas toujours).
# Entrée est RESTORE, Échap est Cancel, un nom vide est une annulation.
#
# L'archive vient du geste (le clic d'une ligne) : rien à choisir ici — sans
# archive, il n'y a rien à demander.
class WpfRestoreView : BaseViewWpf {
    [object] Ask([object[]]$rows, [string]$target) {
        $self = $this
        $archiveName = "$target"
        if (-not $archiveName) { return $null }

        $this.Title = "Restore archive"
        $this.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
        $this.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $this.ResizeMode = [System.Windows.ResizeMode]::NoResize
        $this.Load((Join-Path $PSScriptRoot "Restore.xaml"))
        $this.WearDefault()
        $this.Dress($null, 15)

        $this.Find("TxtLead").Text = "The archive '$archiveName' comes back as a new instance."
        $txtName = $this.Find("TxtName")
        $txtName.Text = $archiveName

        $this.Add_ContentRendered({ $null = $txtName.Focus(); $txtName.SelectAll() })

        $this.Find("BtnRestoreCancel").Add_Click({ $self.Result = $null; $self.Close() })
        $this.Find("BtnRestoreGo").Add_Click({
            $name = "$($txtName.Text)".Trim()
            if (-not $name) { return }
            $dto = [RestoreDto]::new()
            $dto.ArchiveName = $archiveName
            $dto.InstanceName = $name
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
