# ==============================================================================
# LA QUESTION DE LA RACINE — LA VUE WPF
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewWpf.psm1
using module ..\..\..\Tools\Helpers.psm1

# La question du déplacement de la racine : l'avertissement, le dossier
# d'arrivée, Cancel et le CONFIRM rouge. Rend le dossier, ou rien. La garde du
# service est montrée ici : la boîte reste ouverte et dit pourquoi — rien ne
# part pour un chemin impossible.
class WpfRootMoveView : BaseViewWpf {
    [object] Ask([string]$current) {
        $self = $this
        $this.Title = "WSL Stack"
        $this.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
        $this.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $this.ResizeMode = [System.Windows.ResizeMode]::NoResize
        $this.Load((Join-Path $PSScriptRoot "RootMove.xaml"))
        $this.WearDefault()
        $this.Dress($null, 15)

        $this.Find("TxtLead").Text = "Move the fleet from '$current'"
        $this.Find("TxtWarning").Text = "Every instance will be archived and unregistered before migration."
        $txtNewRoot = $this.Find("TxtNewRoot")
        $txtNewRoot.Text = $current
        $this.Add_ContentRendered({ $null = $txtNewRoot.Focus(); $txtNewRoot.SelectAll() })

        $this.Find("BtnRootCancel").Add_Click({ $this.Close() })
        $this.Find("BtnRootOk").Add_Click({
            $chosen = "$($txtNewRoot.Text)".Trim().Trim('"').TrimEnd('\')
            if (-not $chosen -or $chosen -eq "$current".TrimEnd('\')) { return }
            $problem = Test-FleetTarget $chosen
            if ($problem) {
                $this.Find("TxtWarning").Text = $problem
                return
            }
            $this.Result = $chosen
            $this.Close()
        })

        $this.FitToContent($null)
        $null = $this.OpenAs($null)
        return "$($this.Result)"
    }
}
