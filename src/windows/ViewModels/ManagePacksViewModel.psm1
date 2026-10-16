# ==============================================================================
# LES PACKS D'UNE INSTANCE — LE VIEWMODEL
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout lui-même ce qu'il
# tire.
using module .\BaseViewModel.psm1
using module ..\Dtos\InstanceDto.psm1

# Une ligne de la checklist : le nom, la description, et sa case —
# cochée et pas portée entre, portée et décochée sort ; chaque bascule
# rappelle le compte au parent.
class PackRowViewModel : BaseViewModel {
    hidden [object]$_owner = $null
    hidden [string]$_name = ""
    [string]$Label = ""
    [bool]$Checked = $false

    PackRowViewModel([object]$owner, [string]$name, [string]$label, [bool]$checked) {
        $this._owner = $owner
        $this._name = $name
        $this.Label = $label
        $this.Checked = $checked
    }

    # Le lien XAML est à sens unique : la vue relaie la bascule ici — la
    # garde, le cri, et le compte rappelé au parent.
    [void] SetChecked([bool]$on) {
        if ($this.Checked -ne $on) {
            $this.Checked = $on
            $this.OnPropertyChanged("Checked")
            $this._owner.Recount()
        }
    }

    [string] PackName() {
        return $this._name
    }
}

# La checklist du service, en fenêtre : une case par ligne — les offrables
# décochées, les portables cochées —, et sous elles les deux lignes du cli
# (Will install / Will remove), calculées du même écart. Les requirements, les
# invisibles et les refus se résolvent au service, à l'application. APPLY ne
# s'éveille que si quelque chose entre ou sort.
class ManagePacksViewModel : BaseViewModel {
    hidden [object]$_packs = $null
    hidden [string]$_name = ""
    [object[]]$PackRows = @()
    [string]$Lead = ""
    [string]$WillAdd = ""
    [string]$WillRemove = ""
    hidden [bool]$_canApply = $false
    hidden [bool]$_empty = $false

    [object]$Result = $null
    [System.Windows.Input.ICommand]$ApplyCommand

    ManagePacksViewModel([object]$packs, [string]$name) {
        $this._packs = $packs
        $this._name = "$name"
        $this.Lead = ("Packs for '$name'").ToUpperInvariant()

        $installed = @($packs.Installed)
        $rows = @()
        foreach ($pack in @($packs.Candidate)) {
            $rows += [PSCustomObject]@{ Name = "$($pack.Name)"; Label = ("{0,-12} {1}" -f "$($pack.Name)", "$($pack.Description)"); Checked = $false }
        }
        foreach ($removable in @($packs.Removable)) {
            if (@($rows | Where-Object { $_.Name -eq "$removable" }).Count -gt 0) { continue }
            $rows += [PSCustomObject]@{ Name = "$removable"; Label = "$removable"; Checked = $true }
        }
        if ($rows.Count -eq 0) { $this._empty = $true; return }

        $built = @()
        foreach ($row in $rows) {
            $built += [PackRowViewModel]::new($this, "$($row.Name)", "$($row.Label)", [bool]$row.Checked)
        }
        $this.PackRows = @($built)

        $this.ApplyCommand = $this.NewCommand({ param($vm) $vm.Apply() }, { param($vm) $vm.CanApply() })
        $this.Recount()
    }

    [bool] Empty() {
        return $this._empty
    }

    # L'écart : cochée et pas portée entre, portée et décochée sort.
    [void] Recount() {
        $installed = @($this._packs.Installed)
        $ticked = @($this.PackRows | Where-Object { $_.Checked } | ForEach-Object { $_.PackName() })
        $toAdd = @($ticked | Where-Object { $installed -notcontains $_ })
        $toRemove = @($this._packs.Removable | Where-Object { $ticked -notcontains $_ })
        $this.WillAdd = if ($toAdd.Count -gt 0) { "Will install : $($toAdd -join ', ')" } else { "" }
        $this.WillRemove = if ($toRemove.Count -gt 0) { "Will remove  : $($toRemove -join ', ')" } else { "" }
        $this._canApply = ($toAdd.Count -gt 0 -or $toRemove.Count -gt 0)
        $this.OnPropertyChanged("WillAdd")
        $this.OnPropertyChanged("WillRemove")
        $this.ApplyCommand.RaiseCanExecuteChanged()
    }

    [bool] CanApply() {
        return $this._canApply
    }

    [void] Apply() {
        if (-not $this._canApply) { return }
        $installed = @($this._packs.Installed)
        $ticked = @($this.PackRows | Where-Object { $_.Checked } | ForEach-Object { $_.PackName() })
        $dto = [ManagePacksDto]::new()
        $dto.InstanceName = $this._name
        $dto.ToAdd = @($ticked | Where-Object { $installed -notcontains $_ })
        $dto.ToRemove = @($this._packs.Removable | Where-Object { $ticked -notcontains $_ })
        if ($dto.ToAdd.Count -eq 0 -and $dto.ToRemove.Count -eq 0) { return }
        $this.Result = $dto
        $this.RequestClose()
    }
}
