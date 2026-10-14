# ==============================================================================
# BUILD — LA VUE WPF
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\BaseViewWpf.psm1
using module ..\..\..\Dto\InstanceDto.psm1

# La naissance, la fenêtre d'aujourd'hui : le nom et le compte vérifiés en
# direct (la ligne rouge sous la boîte), la route — Dockerfile, image, ou
# registre — chacune avec sa liste, son upload, son téléchargement et sa
# corbeille (les recettes du dépôt ne se suppriment pas : la corbeille ne
# touche qu'aux téléversées), l'onboarding, et les deux cases. CREATE vérifie,
# lit la famille de la source choisie, ouvre la fenêtre des packs PAR-DESSUS
# (Cancel y revient, le formulaire intact), puis rend le BuildDto entier.
#
# Les écritures de recettes et la porte du registre arrivent liées au service
# ($doors) : la fenêtre n'en sait pas plus. La sonde docker, elle, a été lue
# AVANT : la fenêtre s'ouvre avec la réponse.
class WpfBuildView : BaseViewWpf {
    # Les verdicts vivants des deux boîtes — les poignées écrivent, les
    # locales d'Ask ne leur appartiennent pas.
    hidden [bool]$NameOk = $false
    hidden [bool]$UserOk = $false
    # L'Entrée mangée après un sélecteur de fichier (mesuré).
    hidden [bool]$EatEnter = $false
    # Les portes liées au service — gardées ici : les méthodes de la vue ne
    # voient pas les locales d'Ask.
    hidden [object]$Doors = $null

    [object] Ask([object]$sources, [object[]]$images, [object[]]$packs, [object]$checkRegistry, [object]$doors) {
        $self = $this
        $this.Doors = $doors
        $this.Title = "Add instance"
        $this.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
        $this.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $this.ResizeMode = [System.Windows.ResizeMode]::NoResize
        $this.Load((Join-Path $PSScriptRoot "Build.xaml"))
        $this.WearDefault()
        $this.Dress($null, 15)

        $txtName = $this.Find("TxtName")
        $txtNameError = $this.Find("TxtNameError")
        $txtUser = $this.Find("TxtUser")
        $txtUserError = $this.Find("TxtUserError")
        $txtImageError = $this.Find("TxtImageError")
        $txtRegistry = $this.Find("TxtRegistry")
        $txtRegistryError = $this.Find("TxtRegistryError")
        $lblUser = $this.Find("LblUser")
        $btnCreate = $this.Find("BtnAddCreate")

        # Le compte proposé : le nom Windows, nettoyé — la même règle qu'au
        # cli.
        $proposal = "$env:USERNAME".ToLower()
        $proposal = $proposal.Normalize([Text.NormalizationForm]::FormD) -replace '\p{Mn}', ''
        $proposal = $proposal -replace '[^a-z0-9_-]+', '-'
        $proposal = $proposal.Trim('-', '_')
        if (-not ($proposal -cmatch '^[a-z][a-z0-9_-]*$')) { $proposal = "" }
        $txtUser.Text = $proposal

        $this.Add_ContentRendered({ $null = $txtName.Focus() })

        # Les vérifications vivantes : le nom (forme, pris, dossier), le
        # compte (la forme, quand l'onboarding tourne). CREATE suit les deux.
        $CheckName = {
            $name = "$($txtName.Text)".Trim()
            $problem = ""
            if (-not $name) { $problem = "Give a name." }
            elseif ($name -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*$') { $problem = "Letters, digits, '.', '_' and '-' only." }
            elseif (@($doors.Taken) -contains $name) { $problem = "An instance named '$name' already exists." }
            $txtNameError.Text = $problem
            $txtNameError.Visibility = if ($problem) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
            $self.NameOk = (-not $problem)
            $btnCreate.IsEnabled = [bool]($self.NameOk -and $self.UserOk)
        }
        $CheckUser = {
            $user = "$($txtUser.Text)".Trim()
            $problem = ""
            if ("$user" -cnotmatch '^[a-z][a-z0-9_-]*$') { $problem = "Lowercase letters, digits, '_' and '-' only, starting with a letter." }
            $txtUserError.Text = $problem
            $txtUserError.Visibility = if ($problem) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
            $self.UserOk = (-not $problem)
            $btnCreate.IsEnabled = [bool]($self.NameOk -and $self.UserOk)
        }

        # Les trois listes, en List pour la raison connue : les poignées
        # ajoutent par méthode, une affectation resterait chez le bloc.
        $dockerChoices = [System.Collections.Generic.List[object]]::new()
        $bootChoices = [System.Collections.Generic.List[object]]::new()
        $imageChoices = [System.Collections.Generic.List[object]]::new()
        $cmbDockerfile = $this.Find("CmbDockerfile")
        $cmbFirstBoot = $this.Find("CmbFirstBoot")
        $cmbDockerImage = $this.Find("CmbDockerImage")
        foreach ($row in @($sources.Dockerfiles)) { $dockerChoices.Add($row); $null = $cmbDockerfile.Items.Add("$($row.Name)") }
        foreach ($row in @($sources.Onboardings)) { $bootChoices.Add($row); $null = $cmbFirstBoot.Items.Add("$($row.Name)") }
        foreach ($row in @($images)) { $imageChoices.Add($row); $null = $cmbDockerImage.Items.Add("$($row.Name)") }
        if ($cmbDockerfile.Items.Count -gt 0) { $cmbDockerfile.SelectedIndex = 0 }
        if ($cmbFirstBoot.Items.Count -gt 0) { $cmbFirstBoot.SelectedIndex = 0 }
        if ($cmbDockerImage.Items.Count -gt 0) { $cmbDockerImage.SelectedIndex = 0 }

        # La route : Dockerfile, image, registre — seule la boîte choisie se
        # montre, et l'onboarding suit la route (une image — téléversée ou du
        # registre — est présumée complète ; un Dockerfile garde la case).
        $roads = @([WslBuildType]::Dockerfile, [WslBuildType]::Image, [WslBuildType]::Registry)
        $roadLabels = @("Dockerfile", "Docker image", "Docker registry")
        $cmbRoad = $this.Find("CmbRoad")
        foreach ($label in $roadLabels) { $null = $cmbRoad.Items.Add($label) }
        $cmbRoad.SelectedIndex = 0
        $boxDockerfile = $this.Find("BoxDockerfile")
        $boxImage = $this.Find("BoxDockerImage")
        $boxRegistry = $this.Find("BoxRegistry")
        $chkRunFirstBoot = $this.Find("ChkRunFirstBoot")
        $ShowRecipeBox = {
            $road = $roads[[Math]::Max(0, $cmbRoad.SelectedIndex)]
            $fromImage = ($road -eq [WslBuildType]::Image)
            $fromRegistry = ($road -eq [WslBuildType]::Registry)
            $chkRunFirstBoot.IsChecked = -not ($fromImage -or $fromRegistry)
            $boxDockerfile.Visibility = if ($road -eq [WslBuildType]::Dockerfile) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
            $boxImage.Visibility = if ($fromImage) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
            $boxRegistry.Visibility = if ($fromRegistry) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
        }
        $cmbRoad.Add_SelectionChanged({ & $ShowRecipeBox })

        # L'onboarding : décoché, l'image est prise telle quelle — le compte
        # grise, il n'y a personne à nommer.
        $boxFirstBoot = $this.Find("BoxFirstBoot")
        $UpdateOnboarding = {
            $on = [bool]$chkRunFirstBoot.IsChecked
            $txtUser.IsEnabled = $on
            $lblUser.IsEnabled = $on
            $boxFirstBoot.IsEnabled = $on
            if (-not $on) { $txtUserError.Visibility = [System.Windows.Visibility]::Collapsed }
        }
        # Checked/Unchecked, pas Click : la route coche cette case par code,
        # et une coche programmée ne fait pas de clic.
        $chkRunFirstBoot.Add_Checked({ & $UpdateOnboarding })
        $chkRunFirstBoot.Add_Unchecked({ & $UpdateOnboarding })

        # Les corbeilles : la ligne choisie, téléversée seulement, confirmée
        # avant (la porte rouge), puis le dépôt retire et la liste suit.
        $btnDockerfileDelete = $this.Find("BtnDockerfileDelete")
        $btnFirstBootDelete = $this.Find("BtnFirstBootDelete")
        $btnDockerImageDelete = $this.Find("BtnDockerImageDelete")
        $UpdateTrash = {
            $btnDockerfileDelete.IsEnabled = ($cmbDockerfile.SelectedIndex -ge 0) -and [bool]$dockerChoices[[Math]::Max(0, $cmbDockerfile.SelectedIndex)].Uploaded
            $btnFirstBootDelete.IsEnabled = ($cmbFirstBoot.SelectedIndex -ge 0) -and [bool]$bootChoices[[Math]::Max(0, $cmbFirstBoot.SelectedIndex)].Uploaded
            $btnDockerImageDelete.IsEnabled = ($cmbDockerImage.SelectedIndex -ge 0) -and [bool]$imageChoices[[Math]::Max(0, $cmbDockerImage.SelectedIndex)].Uploaded
        }
        $btnDockerfileDownload = $this.Find("BtnDockerfileDownload")
        $btnFirstBootDownload = $this.Find("BtnFirstBootDownload")
        $btnDockerImageDownload = $this.Find("BtnDockerImageDownload")
        $UpdateDownload = {
            $btnDockerfileDownload.IsEnabled = ($cmbDockerfile.SelectedIndex -ge 0)
            $btnFirstBootDownload.IsEnabled = ($cmbFirstBoot.SelectedIndex -ge 0)
            $btnDockerImageDownload.IsEnabled = ($cmbDockerImage.SelectedIndex -ge 0)
        }
        $cmbDockerfile.Add_SelectionChanged({ & $UpdateTrash; & $UpdateDownload })
        $cmbFirstBoot.Add_SelectionChanged({ & $UpdateTrash; & $UpdateDownload })
        $cmbDockerImage.Add_SelectionChanged({ & $UpdateTrash; & $UpdateDownload })
        & $UpdateTrash
        & $UpdateDownload

        # L'Entrée mangée après chaque sélecteur : à sa fermeture, l'Entrée
        # retombe sur le bouton par défaut — CREATE a déjà fermé la fenêtre
        # une fois ailleurs (mesuré).
        $this.Add_PreviewKeyDown({
            param($source, $e)
            if ($self.EatEnter -and $e.Key -eq [System.Windows.Input.Key]::Enter) { $e.Handled = $true }
        })
        $this.Add_PreviewKeyUp({
            param($source, $e)
            if ($self.EatEnter -and $e.Key -eq [System.Windows.Input.Key]::Enter) {
                $self.EatEnter = $false
                $e.Handled = $true
            }
        })

        # Téléverser : le fichier choisi, la porte liée au service le pose
        # dans son emplacement, la ligne rendue rejoint la liste et se choisit.
        $this.Find("BtnDockerfileUpload").Add_Click({
            $dialog = New-Object Microsoft.Win32.OpenFileDialog
            $dialog.Title = "A Dockerfile for the build"
            $dialog.Filter = "Dockerfiles (Dockerfile*)|Dockerfile*|All files (*.*)|*.*"
            $picked = $dialog.ShowDialog($self)
            $self.EatEnter = $true
            if ($picked -ne $true) { return }
            $up = [UploadRecipeDto]::new()
            $up.Kind = "dockerfiles"
            $up.Source = $dialog.FileName
            $up.FileName = "Dockerfile"
            try { $row = @($doors.Upload.Invoke(@($up)))[0] } catch { return }
            $dockerChoices.Add($row)
            $null = $cmbDockerfile.Items.Add("$($row.Name)")
            $cmbDockerfile.SelectedIndex = $cmbDockerfile.Items.Count - 1
        })
        $this.Find("BtnFirstBootUpload").Add_Click({
            $dialog = New-Object Microsoft.Win32.OpenFileDialog
            $dialog.Title = "An onboarding script for the build"
            $dialog.Filter = "Shell scripts (*.sh)|*.sh|All files (*.*)|*.*"
            $picked = $dialog.ShowDialog($self)
            $self.EatEnter = $true
            if ($picked -ne $true) { return }
            $up = [UploadRecipeDto]::new()
            $up.Kind = "onboardings"
            $up.Source = $dialog.FileName
            $up.FileName = "onboarding.sh"
            try { $row = @($doors.Upload.Invoke(@($up)))[0] } catch { return }
            $bootChoices.Add($row)
            $null = $cmbFirstBoot.Items.Add("$($row.Name)")
            $cmbFirstBoot.SelectedIndex = $cmbFirstBoot.Items.Count - 1
        })
        $this.Find("BtnDockerImageUpload").Add_Click({
            $dialog = New-Object Microsoft.Win32.OpenFileDialog
            $dialog.Title = "A Docker image for the build"
            $dialog.Filter = "Docker images (*.tar)|*.tar|All files (*.*)|*.*"
            $picked = $dialog.ShowDialog($self)
            $self.EatEnter = $true
            if ($picked -ne $true) { return }
            $up = [UploadRecipeDto]::new()
            $up.Kind = "dockerimages"
            $up.Source = $dialog.FileName
            $up.FileName = [IO.Path]::GetFileName($dialog.FileName)
            try { $row = @($doors.Upload.Invoke(@($up)))[0] } catch { return }
            $imageChoices.Add($row)
            $null = $cmbDockerImage.Items.Add("$($row.Name)")
            $cmbDockerImage.SelectedIndex = $cmbDockerImage.Items.Count - 1
        })

        # Télécharger : le fichier de la ligne choisie, sous le nom qu'il fut
        # téléversé (l'empreinte retirée), où l'utilisateur pointe.
        $this.Find("BtnDockerfileDownload").Add_Click({
            $at = $cmbDockerfile.SelectedIndex
            if ($at -lt 0) { return }
            $self.SaveRecipeOut($dockerChoices[$at])
        })
        $this.Find("BtnFirstBootDownload").Add_Click({
            $at = $cmbFirstBoot.SelectedIndex
            if ($at -lt 0) { return }
            $self.SaveRecipeOut($bootChoices[$at])
        })
        $this.Find("BtnDockerImageDownload").Add_Click({
            $at = $cmbDockerImage.SelectedIndex
            if ($at -lt 0) { return }
            $self.SaveRecipeOut($imageChoices[$at])
        })

        # La corbeille : la porte rouge d'abord, le dépôt retire ensuite, la
        # liste suit — une recette du dépôt n'a pas de corbeille.
        $this.Find("BtnDockerfileDelete").Add_Click({
            $at = $cmbDockerfile.SelectedIndex
            if ($at -lt 0) { return }
            $row = $dockerChoices[$at]
            if (-not $row.Uploaded) { return }
            if (-not $self.ConfirmAs($self, "Delete Dockerfile", "Remove '$($row.Name)' from the available Dockerfiles?", "")) { return }
            try { $null = $doors.Delete.Invoke(@("$($row.Path)")) } catch { return }
            $dockerChoices.RemoveAt($at)
            $cmbDockerfile.Items.RemoveAt($at)
            if ($cmbDockerfile.Items.Count -gt 0) { $cmbDockerfile.SelectedIndex = 0 }
            & $UpdateTrash
            & $UpdateDownload
        })
        $this.Find("BtnFirstBootDelete").Add_Click({
            $at = $cmbFirstBoot.SelectedIndex
            if ($at -lt 0) { return }
            $row = $bootChoices[$at]
            if (-not $row.Uploaded) { return }
            if (-not $self.ConfirmAs($self, "Delete onboarding shell", "Remove '$($row.Name)' from the available onboarding shells?", "")) { return }
            try { $null = $doors.Delete.Invoke(@("$($row.Path)")) } catch { return }
            $bootChoices.RemoveAt($at)
            $cmbFirstBoot.Items.RemoveAt($at)
            if ($cmbFirstBoot.Items.Count -gt 0) { $cmbFirstBoot.SelectedIndex = 0 }
            & $UpdateTrash
            & $UpdateDownload
        })
        $this.Find("BtnDockerImageDelete").Add_Click({
            $at = $cmbDockerImage.SelectedIndex
            if ($at -lt 0) { return }
            $row = $imageChoices[$at]
            if (-not $row.Uploaded) { return }
            if (-not $self.ConfirmAs($self, "Delete Docker image", "Remove '$($row.Name)' from the available Docker images?", "")) { return }
            try { $null = $doors.Delete.Invoke(@("$($row.Path)")) } catch { return }
            $imageChoices.RemoveAt($at)
            $cmbDockerImage.Items.RemoveAt($at)
            if ($cmbDockerImage.Items.Count -gt 0) { $cmbDockerImage.SelectedIndex = 0 }
            & $UpdateTrash
            & $UpdateDownload
        })

        $txtName.Add_TextChanged($CheckName)
        $txtUser.Add_TextChanged($CheckUser)
        & $CheckName
        & $CheckUser
        & $ShowRecipeBox
        & $UpdateOnboarding

        # Les deux cases du bas, et la sonde déjà répondue : Docker absent,
        # la boîte système le dit — le formulaire reste ouvert, la création
        # attendra Docker plus tard.
        $chkSaveImage = $this.Find("ChkSaveImage")
        $chkRegisterDocker = $this.Find("ChkRegisterDocker")

        $this.Find("BtnAddCancel").Add_Click({ $self.Result = $null; $self.Close() })
        $btnCreate.Add_Click({
            & $CheckName
            $runFirstBoot = [bool]$chkRunFirstBoot.IsChecked
            if ($runFirstBoot) { & $CheckUser } else { $self.UserOk = $true }
            $road = $roads[[Math]::Max(0, $cmbRoad.SelectedIndex)]
            $fromImage = ($road -eq [WslBuildType]::Image)
            $fromRegistry = ($road -eq [WslBuildType]::Registry)

            # Les lignes rouges sont le refus : les dire et rester ouvert.
            $registryRef = "$($txtRegistry.Text)".Trim()
            $imageProblem = if ($fromImage -and $cmbDockerImage.SelectedIndex -lt 0) { "Upload a Docker image first." } else { "" }
            $txtImageError.Text = $imageProblem
            $txtImageError.Visibility = if ($imageProblem) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }

            $registryProblem = ""
            if ($fromRegistry) {
                if (-not $registryRef) {
                    $registryProblem = "Name the image first, e.g. alpine:latest."
                } else {
                    # Le registre est demandé — pas de pull — et un nom inconnu
                    # se refuse ici, sur la ligne rouge, pas à la naissance.
                    $verdict = @($checkRegistry.Invoke(@($registryRef)))[0]
                    if (-not $verdict.Valid) { $registryProblem = "Unknown registry image '$registryRef' - $($verdict.Why)" }
                }
            }
            $txtRegistryError.Text = $registryProblem
            $txtRegistryError.Visibility = if ($registryProblem) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
            if (-not $self.NameOk -or -not $self.UserOk -or $imageProblem -or $registryProblem) { return }

            # La famille : lue sur la ligne choisie (le FROM est déjà lu) —
            # la fenêtre des packs s'ouvre PAR-DESSUS, le formulaire figé
            # derrière ; Cancel y revient, intact.
            $family = if ($fromImage -or $fromRegistry) { "" } else { "$($dockerChoices[[Math]::Max(0, $cmbDockerfile.SelectedIndex)].Family)" }
            $pickedPacks = $self.AskPacksForBuild("$($txtName.Text)".Trim(), $family, $packs)
            if ($null -eq $pickedPacks) { return }

            $dto = [BuildDto]::new()
            $dto.Name = "$($txtName.Text)".Trim()
            $dto.User = if ($runFirstBoot) { "$($txtUser.Text)".Trim() } else { "" }
            if ($fromRegistry) {
                $dto.BuildType = [WslBuildType]::Registry
                $dto.BuildPath = $registryRef
            } elseif ($fromImage) {
                $dto.BuildType = [WslBuildType]::Image
                $dto.BuildPath = "$($imageChoices[$cmbDockerImage.SelectedIndex].Path)"
            } else {
                $dto.BuildType = [WslBuildType]::Dockerfile
                $dto.BuildPath = "$($dockerChoices[[Math]::Max(0, $cmbDockerfile.SelectedIndex)].Path)"
                $dto.Context = Split-Path -Parent $dto.BuildPath
            }
            $dto.Onboarding = if ($runFirstBoot -and $bootChoices.Count -gt 0) { "$($bootChoices[[Math]::Max(0, $cmbFirstBoot.SelectedIndex)].Path)" } else { "" }
            $dto.Packs = @($pickedPacks)
            $dto.KeepImage = [bool]$chkSaveImage.IsChecked
            $dto.RegisterDocker = [bool]$chkRegisterDocker.IsChecked
            $self.Result = $dto
            $self.Close()
        })

        $this.FitToContent($null)
        $null = $this.OpenAs($null)
        return $this.Result
    }

    # Le téléchargement d'une ligne : le dialogue, puis la porte liée au
    # service. Le nom proposé est celui du téléversement — l'empreinte au nom
    # de l'emplacement retirée.
    hidden [void] SaveRecipeOut([object]$row) {
        $base = (Split-Path -Path (Split-Path -Path "$($row.Path)" -Parent) -Leaf) -replace '-[0-9a-f]{8}$', ''
        $save = New-Object Microsoft.Win32.SaveFileDialog
        $save.Title = "Save '$($row.Name)'"
        $save.FileName = "$base$([IO.Path]::GetExtension("$($row.Path)"))"
        $save.Filter = "All files (*.*)|*.*"
        $picked = $save.ShowDialog($this)
        $this.EatEnter = $true
        if ($picked -ne $true) { return }
        try {
            $exp = [ExportRecipeDto]::new()
            $exp.Path = "$($row.Path)"
            $exp.Target = $save.FileName
            $null = $this.Doors.Export.Invoke(@($exp))
        } catch { }
    }

    # La fenêtre des packs de la naissance, par-dessus le formulaire : les
    # lignes de la famille choisie (toutes quand elle est illisible — et
    # c'est dit), le socle pré-coché quand elle colle. APPLY rend les noms ;
    # Cancel rend $null et le formulaire reprend la main ; rien de coché est
    # une réponse — il naîtra nu.
    hidden [object] AskPacksForBuild([string]$name, [string]$family, [object[]]$packs) {
        $pick = [BaseViewWpf]::new()
        $pick.Title = "Packs for the build"
        $pick.SizeToContent = [System.Windows.SizeToContent]::WidthAndHeight
        $pick.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen
        $pick.ResizeMode = [System.Windows.ResizeMode]::NoResize
        $pick.Load((Join-Path $PSScriptRoot "BuildPacks.xaml"))
        $pick.WearDefault()
        $pick.Dress($null, 15)

        if (-not $family) { $pick.Find("TxtPacksForeign").Visibility = [System.Windows.Visibility]::Visible }

        $offered = if ($family) { @($packs | Where-Object { $_.Family -eq $family }) } else { @($packs) }
        $panel = $pick.Find("Boxes")
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

        $txtNotes = $pick.Find("TxtNotes")
        $Refresh = {
            $ticked = @($entries | Where-Object { $_.Check.IsChecked })
            $txtNotes.Text = if ($ticked.Count -eq 0) { "No pack selected - it will start bare." } else { "" }
        }
        foreach ($entry in $entries) {
            $entry.Check.Add_Checked({ & $Refresh })
            $entry.Check.Add_Unchecked({ & $Refresh })
        }
        & $Refresh

        $pick.Find("BtnPickCancel").Add_Click({ $pick.Close() })
        $pick.Find("BtnPickApply").Add_Click({
            $names = @($entries | Where-Object { $_.Check.IsChecked } | ForEach-Object { "$($_.Pack.Name)" })
            $pick.Result = @($names)
            $pick.Close()
        })

        $pick.FitToContent($this)
        $null = $pick.OpenAs($this)
        if ($null -eq $pick.Result) { return $null }
        return ,$pick.Result
    }

    # Le rapport — la ligne d'état de la fenêtre principale le porte.
    [void] Show([string]$name, [object]$response) {
    }
}
