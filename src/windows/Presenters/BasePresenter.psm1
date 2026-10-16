class BasePresenter {
    hidden [string]$ViewsRoot
    hidden [string]$ViewType
    hidden [string]$ViewFolder
    hidden [hashtable]$Loaded = @{}

    [hashtable]$Views = @{}

    BasePresenter([string]$viewsRoot, [string]$viewType, [string]$viewFolder) {
        $this.ViewsRoot = $viewsRoot
        $this.ViewType = $viewType
        $this.ViewFolder = $viewFolder
    }

    hidden [object] GetView([string]$gesture) {
        if ($this.Views.ContainsKey($gesture)) { return $this.Views[$gesture] }

        $this.ImportView($gesture)

        $prefix = $this.ViewType.Substring(0, 1).ToUpper() + $this.ViewType.Substring(1).ToLower()
        $className = "$prefix$gesture" + "View"

        $found = $null
        foreach ($assembly in [AppDomain]::CurrentDomain.GetAssemblies()) {
            try { $found = @($assembly.GetTypes() | Where-Object { $_.Name -eq $className })[0] } catch { }
            if ($found) { break }
        }
        if (-not $found) {
            throw "No $($this.ViewType) view class '$className' for '$gesture'."
        }

        return $found::new()
    }

    hidden [void] ImportView([string]$gesture) {
        if ($this.Loaded.ContainsKey($gesture)) { return }

        $typeRoot = Join-Path $this.ViewsRoot $this.ViewType
        $folders = @(
            (Join-Path $typeRoot $this.ViewFolder),
            (Join-Path (Join-Path $typeRoot $this.ViewFolder) "shared"),
            (Join-Path $typeRoot "shared")
        )
        $modulePath = ""
        foreach ($folder in $folders) {
            foreach ($name in @("$gesture.psm1", "$gesture.xaml.ps1")) {
                $candidate = Join-Path $folder $name
                if (Test-Path $candidate) { $modulePath = $candidate; break }
            }
            if ($modulePath) { break }
        }
        if (-not $modulePath) {
            throw "No $($this.ViewType) view for '$gesture' under '$typeRoot'."
        }
        $null = Import-Module $modulePath -Force
        $this.Loaded[$gesture] = $true
    }

    hidden [void] ShowFailure([string]$message) {
        $view = $this.GetView("Error")
        $view.Show($message)
    }
}
