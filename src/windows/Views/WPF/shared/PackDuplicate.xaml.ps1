# ==============================================================================
# LA COPIE D'UN PACK — LA VUE WPF
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewWpf.psm1

# La petite fenêtre de duplication d'un pack : le nom (source-copy proposé,
# pris refusé) et la description. Rend le nom et la description, ou rien.
class WpfPackDuplicateView : BaseViewWpf {
    [object] Ask([string]$source, [string]$description, [string[]]$taken) {
        $self = $this
        $this.Title = "WSL Stack"
        $this.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
        $this.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $this.ResizeMode = [System.Windows.ResizeMode]::NoResize
        $this.Load((Join-Path $PSScriptRoot "PackDuplicate.xaml"))
        $this.WearDefault()
        $this.Dress($null, 15)

        $this.Find("TxtLead").Text = "Duplicate the pack '$source'"
        $txtDupName = $this.Find("TxtDupName")
        $txtDupName.Text = "$source-copy"
        $this.Find("TxtDupDescription").Text = $description
        $txtDupError = $this.Find("TxtDupError")
        $this.Add_ContentRendered({ $null = $txtDupName.Focus(); $txtDupName.SelectAll() })

        $this.Find("BtnDupCancel").Add_Click({ $this.Close() })
        $this.Find("BtnDupOk").Add_Click({
            $chosen = "$($txtDupName.Text)".Trim()
            $problem = ""
            if ($chosen -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*$') {
                $problem = "Letters, digits, '.', '_' and '-' only, starting with a letter or a digit."
            } elseif (@($taken | Where-Object { $_ -eq $chosen }).Count -gt 0) {
                $problem = "A pack named '$chosen' already exists."
            }
            if ($problem) {
                $txtDupError.Text = $problem
                $txtDupError.Visibility = [System.Windows.Visibility]::Visible
                return
            }
            $this.Result = [PSCustomObject]@{ Name = $chosen; Description = "$($this.Find("TxtDupDescription").Text)".Trim() }
            $this.Close()
        })

        $this.FitToContent($null)
        $null = $this.OpenAs($null)
        return $this.Result
    }
}
