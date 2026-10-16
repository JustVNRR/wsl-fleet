using module ..\Entities\WslInstance.psm1
using module ..\Entities\WslTheme.psm1

class InstanceRepository {
    hidden [string]$InstancesRoot

    InstanceRepository([string]$instancesRoot) {
        $this.InstancesRoot = $instancesRoot
    }

    [void] ReRoot([string]$root) {
        $this.InstancesRoot = $root
    }

    [string] GetFolder([string]$name) {
        return (Join-Path $this.InstancesRoot $name)
    }

    [WslInstance] GetInstance([string]$name) {
        $instance = [WslInstance]::new()
        $instance.SetName($name)
        $file = Join-Path $this.GetFolder($name) "instance.json"
        if (-not (Test-Path $file)) { return $instance }
        try {
            $saved = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
        } catch {
            return $instance
        }
        if ($saved.DefaultUser) { $instance.SetDefaultUser("$($saved.DefaultUser)") }
        if ($saved.Theme) {
            $theme = [WslTheme]::new()
            if ($saved.Theme.Font) { $theme.SetFont("$($saved.Theme.Font)") }
            if ($saved.Theme.ColorScheme) { $theme.SetColourScheme("$($saved.Theme.ColorScheme)") }
            if ($saved.Theme.IconFrom) { $theme.SetIconPath("$($saved.Theme.IconFrom)") }
            $theme.SetIcon([PSCustomObject]@{
                Text      = "$($saved.Theme.IconText)"
                Top       = "$($saved.Theme.IconTop)"
                Bottom    = "$($saved.Theme.IconBottom)"
                TextColor = "$($saved.Theme.IconTextColor)"
            })
            $instance.SetTheme($theme)
        }
        return $instance
    }

    [void] SaveInstance([WslInstance]$instance, [string]$docker) {
        $theme = $instance.GetTheme()
        if ($null -eq $theme) { $theme = [WslTheme]::new() }

        $block = [ordered]@{
            Font        = "$($theme.GetFontName())"
            ColorScheme = "$($theme.GetColorScheme())"
            IconFrom    = "$($theme.GetIconPath())"
        }
        $icon = $theme.GetIcon()
        if ($icon.Text) {
            $block.IconText      = "$($icon.Text)"
            $block.IconTop       = "$($icon.Top)"
            $block.IconBottom    = "$($icon.Bottom)"
            $block.IconTextColor = "$($icon.TextColor)"
        }

        $content = [ordered]@{
            DefaultUser = "$($instance.GetDefaultUser())"
            Theme       = [PSCustomObject]$block
        }
        if ($docker) { $content.Docker = $docker }
        $content | ConvertTo-Json -Depth 4 |
            Set-Content -LiteralPath (Join-Path $this.GetFolder($instance.GetName()) "instance.json") -Encoding utf8NoBOM
    }

    [string] GetSavedDocker([string]$name) {
        $file = Join-Path $this.GetFolder($name) "instance.json"
        if (-not (Test-Path $file)) { return "" }
        try { $saved = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json } catch { return "" }
        return "$($saved.Docker)"
    }

    [void] SaveIcon([string]$name, [string]$source) {
        Copy-Item -LiteralPath $source -Destination (Join-Path $this.GetFolder($name) "terminal-icon.png") -Force
    }

    [void] WriteMarker([string]$name, [string]$by) {
        $folder = $this.GetFolder($name)
        if (-not (Test-Path $folder)) { return }
        $marker = [ordered]@{
            template = "wsl-fleet"
            created  = (Get-Date).ToString("yyyy-MM-dd")
            by       = $by
        }
        $json = ($marker | ConvertTo-Json) -replace "`r`n", "`n"
        [System.IO.File]::WriteAllText((Join-Path $folder ".wsl-fleet"), $json,
            (New-Object System.Text.UTF8Encoding($false)))
    }

    [bool] HasMarker([string]$name) {
        return $this.HasMarkerIn($this.GetFolder($name))
    }

    [bool] HasMarkerIn([string]$folder) {
        if (-not $folder) { return $false }
        return (Test-Path (Join-Path $folder ".wsl-fleet"))
    }

    [string[]] GetMarkedFolders() {
        $names = @()
        if (-not (Test-Path $this.InstancesRoot)) { return @() }
        foreach ($dir in (Get-ChildItem -Path $this.InstancesRoot -Directory -ErrorAction SilentlyContinue | Sort-Object Name)) {
            if (Test-Path (Join-Path $dir.FullName ".wsl-fleet")) { $names += $dir.Name }
        }
        return @($names)
    }

    [long] GetVhdxSize([string]$name) {
        $vhdx = Join-Path $this.GetFolder($name) "ext4.vhdx"
        if (Test-Path $vhdx) { return [long](Get-Item -LiteralPath $vhdx).Length }
        return 0
    }

    [string] GetIconPath([string]$name) {
        return (Join-Path $this.GetFolder($name) "terminal-icon.png")
    }

    [bool] HasIcon([string]$name) {
        return (Test-Path $this.GetIconPath($name))
    }

    [bool] IsFolderOccupied([string]$name) {
        $folder = $this.GetFolder($name)
        return (Test-Path $folder) -and (@(Get-ChildItem -Path $folder -Force).Count -gt 0)
    }

    [void] RemoveFolder([string]$name) {
        Remove-Item -LiteralPath $this.GetFolder($name) -Recurse -Force -ErrorAction SilentlyContinue
    }

    [void] EnsureFolder([string]$folder) {
        $null = New-Item -ItemType Directory -Path $folder -Force -ErrorAction Stop
    }

    [long] GetFreeSpace([string]$path) {
        $full = [System.IO.Path]::GetFullPath($path)
        $volume = New-Object System.IO.DriveInfo([System.IO.Path]::GetPathRoot($full))
        return [long]$volume.AvailableFreeSpace
    }

    [datetime] GetCreatedAt([string]$name) {
        $folder = $this.GetFolder($name)
        if (-not (Test-Path $folder)) { return [datetime]::MinValue }
        return (Get-Item -LiteralPath $folder).CreationTime
    }
}
