# ==============================================================================
# LES PACKS D'UNE INSTANCE — LE VIEWMODEL
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout lui-même ce qu'il
# tire.
using module .\BaseViewModel.psm1
using module ..\Dto\InstanceDto.psm1

# Une ligne de la checklist : le nom, la description, et sa case —
# cochée et pas portée entre, portée et décochée sort ; chaque bascule
# rappelle le compte au parent.
class PackRowViewModel : BaseViewModel {
    hidden [object]$_owner = $null
    hidden [bool]$_checked = $false
    hidden [string]$_name = ""
    hidden [string]$_label = ""

    PackRowViewModel([object]$owner, [string]$name, [string]$label, [bool]$checked) {
        $this._owner = $owner
        $this._name = $name
        $this._label = $label
        $this._checked = $checked
        $this.AddProperty("Label", { return $this._label }, { param($value) })
        $this.AddProperty("Checked", { return $this._checked }, {
            param($value)
            if ($this._checked -ne [bool]$value) {
                $this._checked = [bool]$value
                $this.OnPropertyChanged("Checked")
                $this._owner.Recount()
            }
        })
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
    hidden [object[]]$_packRows = @()
    hidden [string]$_lead = ""
    hidden [string]$_willAdd = ""
    hidden [string]$_willRemove = ""
    hidden [bool]$_canApply = $false
    hidden [bool]$_empty = $false

    [object]$Result = $null
    [System.Windows.Input.ICommand]$ApplyCommand

    ManagePacksViewModel([object]$packs, [string]$name) {
        $this._packs = $packs
        $this._name = "$name"
        $this._lead = "Packs for '$name'"

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
        $this._packRows = @($built)

        $this.AddProperty("Lead", { return $this._lead }, { param($value) })
        $this.AddProperty("PackRows", { return $this._packRows }, { param($value) })
        $this.AddProperty("WillAdd", { return $this._willAdd }, {
            param($value)
            if ($this._willAdd -ne "$value") { $this._willAdd = "$value"; $this.OnPropertyChanged("WillAdd") }
        })
        $this.AddProperty("WillRemove", { return $this._willRemove }, {
            param($value)
            if ($this._willRemove -ne "$value") { $this._willRemove = "$value"; $this.OnPropertyChanged("WillRemove") }
        })

        $this.ApplyCommand = $this.NewCommand({ param($vm) $vm.Apply() }, { param($vm) $vm.CanApply() })
        $this.Recount()
    }

    [bool] Empty() {
        return $this._empty
    }

    # L'écart : cochée et pas portée entre, portée et décochée sort.
    [void] Recount() {
        $installed = @($this._packs.Installed)
        $ticked = @($this._packRows | Where-Object { $_.Checked } | ForEach-Object { $_.PackName() })
        $toAdd = @($ticked | Where-Object { $installed -notcontains $_ })
        $toRemove = @($this._packs.Removable | Where-Object { $ticked -notcontains $_ })
        $this._willAdd = if ($toAdd.Count -gt 0) { "Will install : $($toAdd -join ', ')" } else { "" }
        $this._willRemove = if ($toRemove.Count -gt 0) { "Will remove  : $($toRemove -join ', ')" } else { "" }
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
        $ticked = @($this._packRows | Where-Object { $_.Checked } | ForEach-Object { $_.PackName() })
        $dto = [ManagePacksDto]::new()
        $dto.InstanceName = $this._name
        $dto.ToAdd = @($ticked | Where-Object { $installed -notcontains $_ })
        $dto.ToRemove = @($this._packs.Removable | Where-Object { $ticked -notcontains $_ })
        if ($dto.ToAdd.Count -eq 0 -and $dto.ToRemove.Count -eq 0) { return }
        $this.Result = $dto
        $this.OnPropertyChanged("Done")
    }
}
