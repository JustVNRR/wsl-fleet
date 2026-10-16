using module .\BaseViewModel.psm1
using module ..\Dtos\InstanceDto.psm1

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
