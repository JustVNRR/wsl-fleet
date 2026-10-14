# ==============================================================================
# GETPACKS — LA VUE WPF
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewWpf.psm1

# Les packs d'une instance, en fenêtre : ce qu'elle porte, ce qui s'offre, ce
# qui se retire — le rapport du cli, rien à demander, CLOSE.
class WpfGetPacksView : BaseViewWpf {
    [void] Show([string]$name, [object]$response) {
        $self = $this
        $this.Title = "Packs"
        $this.Width = 560
        $this.SizeToContent = [System.Windows.SizeToContent]::Height
        $this.MaxHeight = 760
        $this.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $this.ResizeMode = [System.Windows.ResizeMode]::NoResize
        $this.Load((Join-Path $PSScriptRoot "GetPacks.xaml"))
        $this.WearDefault()
        $this.Dress($null, 15)

        $this.Find("TxtLead").Text = "Packs of '$name':"
        $this.Find("TxtCarried").Text = if ($response.Installed.Count -eq 0) {
            "  * Carried          : none"
        } else {
            "  * Carried          : $($response.Installed -join ', ')"
        }
        $this.Find("TxtOffered").Text = if ($response.Candidate.Count -gt 0) {
            $names = @($response.Candidate | ForEach-Object { $_.Name })
            "  * Offered          : $($names -join ', ')"
        } else { "" }
        $this.Find("TxtRemovable").Text = if ($response.Removable.Count -gt 0) {
            "  * Removable        : $($response.Removable -join ', ')"
        } else { "" }

        $this.Find("BtnPacksClose").Add_Click({ $self.Close() })

        $this.FitToContent($null)
        $null = $this.OpenAs($null)
    }
}
