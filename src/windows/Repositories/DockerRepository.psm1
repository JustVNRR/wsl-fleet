using module ..\Tools\Native.psm1

class DockerRepository {
    hidden [string]$AssetsDir

    DockerRepository([string]$assetsDir) {
        $this.AssetsDir = $assetsDir
    }

    [hashtable] TestRegistryImage([string]$reference) {
        if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
            return @{ Ok = $false; Why = "docker is not on the PATH." }
        }

        $onHub = $true
        $segments = $reference.Split("/")
        if ($segments.Count -gt 1) {
            $first = $segments[0]
            if ($first.Contains(".") -or $first.Contains(":") -or $first -eq "localhost") { $onHub = $false }
        }
        if ($reference.Contains("@")) { $onHub = $false }

        $curl = Get-Command curl -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($onHub -and $curl) {
            $name = $reference
            $tag = "latest"
            $colon = $reference.LastIndexOf(":")
            if ($colon -ge 0) {
                $name = $reference.Substring(0, $colon)
                $tag = $reference.Substring($colon + 1)
            }
            if (-not $name.Contains("/")) { $name = "library/$name" }
            $url = "https://hub.docker.com/v2/repositories/$name/tags/$tag"

            $previousEAP = $global:ErrorActionPreference
            $global:ErrorActionPreference = "Continue"
            $sink = if ("$env:OS" -eq "Windows_NT") { "NUL" } else { "/dev/null" }
            $answer = @(& $curl.Path -s -o $sink -w "%{http_code}" -I $url 2>&1)
            $global:ErrorActionPreference = $previousEAP
            $http = "$($answer[-1])".Trim()

            if ($http -eq "200") { return @{ Ok = $true; Why = "" } }
            if ($http -eq "404") { return @{ Ok = $false; Why = "no such image or tag on Docker Hub." } }
            if ($http -eq "000") { return @{ Ok = $false; Why = "Docker Hub could not be reached." } }
            return @{ Ok = $false; Why = "Docker Hub answered '$http'." }
        }

        $previousEAP = $global:ErrorActionPreference
        $global:ErrorActionPreference = "Continue"
        $output = @(& docker manifest inspect $reference 2>&1)
        $code = $global:LASTEXITCODE
        $global:ErrorActionPreference = $previousEAP

        if ($code -eq 0) { return @{ Ok = $true; Why = "" } }

        $why = ""
        foreach ($line in $output) {
            if ("$line") { $why = "$line"; break }
        }
        if (-not $why) { $why = "docker exited with code $code." }
        return @{ Ok = $false; Why = $why }
    }

    [void] Build([string]$tag, [string]$dockerfile, [string]$context) {
        $arguments = 'build -t {0} -f "{1}" "{2}"' -f $tag, $dockerfile, $context
        $process = Start-Process docker -ArgumentList $arguments -NoNewWindow -PassThru
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) {
            throw "Docker build failed. (Exit code: $($process.ExitCode))"
        }
    }

    [string] Load([string]$tarPath) {
        $previousEAP = $global:ErrorActionPreference
        $global:ErrorActionPreference = "Continue"
        $output = @(& docker load -i $tarPath 2>&1)
        $code = $global:LASTEXITCODE
        $global:ErrorActionPreference = $previousEAP
        if ($code -ne 0) {
            throw "The Docker image could not be loaded:`n$($output -join "`n")"
        }
        $loaded = $null
        foreach ($line in $output) {
            if ("$line" -match '^Loaded image(?: ID)?: (.+)$') { $loaded = $Matches[1].Trim(); break }
        }
        if (-not $loaded) { throw "docker load told nothing usable about the image in '$tarPath'." }
        return $loaded
    }

    [void] ExportRootfs([string]$imageName, [string]$outputPath) {
        $container = "wsl-temp-export-$([guid]::NewGuid().ToString().Substring(0, 8))"
        try {
            Invoke-NativeCommand -Program "docker" -Arguments @("create", "--name", $container, $imageName) -Message "Docker could not create a container from '$imageName' (its own words are above)."
            Invoke-NativeCommand -Program "docker" -Arguments @("export", "-o", $outputPath, $container) -Message "Docker export failed."
        } finally {
            $null = Test-NativeCommand -Program "docker" -Arguments @("rm", "-f", $container)
        }
    }

    [bool] SaveImage([string]$tag, [string]$outputPath) {
        $folder = Split-Path $outputPath -Parent
        if (-not (Test-Path $folder)) { $null = New-Item -ItemType Directory -Path $folder -Force }
        return (Test-NativeCommand -Program "docker" -Arguments @("save", "-o", $outputPath, $tag))
    }

    [bool] RemoveImage([string]$tag) {
        return (Test-NativeCommand -Program "docker" -Arguments @("rmi", "-f", $tag))
    }

    [bool] RestartDesktop() {
        return (Test-NativeCommand -Program "docker" -Arguments @("desktop", "restart"))
    }

    [bool] StartDesktop() {
        try {
            Start-Process (Join-Path $env:ProgramFiles "Docker\Docker\Docker Desktop.exe") -ErrorAction Stop
            return $true
        } catch {
            return (Test-NativeCommand -Program "docker" -Arguments @("desktop", "start"))
        }
    }

    [bool] TestRunning() {
        try {
            return (Test-NativeCommand -Program "docker" -Arguments @("info"))
        } catch {
            return $false
        }
    }

    [string] GetSavedImagePath([string]$name) {
        return (Join-Path $this.AssetsDir "dockerimages\$name\$name.tar")
    }

    [object[]] GetAllSavedImages() {
        $images = @()
        $imageRoot = Join-Path $this.AssetsDir "dockerimages"
        if (-not (Test-Path $imageRoot)) { return @() }
        foreach ($slot in @(Get-ChildItem $imageRoot -Directory | Sort-Object Name)) {
            $file = @(Get-ChildItem -LiteralPath $slot.FullName -File | Select-Object -First 1)
            if ($file.Count -eq 0) { continue }
            $images += [PSCustomObject]@{
                Name = [IO.Path]::GetFileNameWithoutExtension($file[0].Name)
                Path = $file[0].FullName
                Modified = $file[0].LastWriteTime
            }
        }
        return @($images)
    }

    [object] GetDesktopNames() {
        $settings = $this.DesktopSettingsPath()
        if (-not $settings -or -not (Test-Path $settings)) { return $null }
        try {
            $config = Get-Content $settings -Raw | ConvertFrom-Json
            $names = @()
            foreach ($one in @($config.IntegratedWslDistros)) {
                if ($one) { $names += "$one" }
            }
            return @($names)
        } catch {
            return $null
        }
    }

    [string] GetDesktopState([string]$instanceName) {
        $settings = $this.DesktopSettingsPath()
        if (-not $settings -or -not (Test-Path $settings)) { return "unknown" }
        try {
            $config = Get-Content $settings -Raw | ConvertFrom-Json
            if (@($config.IntegratedWslDistros) -contains $instanceName) { return "yes" }
            return "no"
        } catch {
            return "unknown"
        }
    }

    [void] SetDesktopState([string]$instanceName) {
        $settings = $this.DesktopSettingsPath()
        $config = Get-Content $settings -Raw | ConvertFrom-Json
        Copy-Item $settings "$settings.bak" -Force
        $config.IntegratedWslDistros = @($config.IntegratedWslDistros | Where-Object { $_ -and $_ -ne $instanceName }) + $instanceName
        $json = ($config | ConvertTo-Json -Depth 10) -replace "`r`n", "`n"
        [System.IO.File]::WriteAllText("$settings.tmp", $json, (New-Object System.Text.UTF8Encoding($false)))
        Move-Item "$settings.tmp" $settings -Force
    }

    [void] RemoveDesktopState([string]$instanceName) {
        $settings = $this.DesktopSettingsPath()
        if (-not $settings -or -not (Test-Path $settings)) { return }
        $config = Get-Content $settings -Raw | ConvertFrom-Json
        if (@($config.IntegratedWslDistros) -notcontains $instanceName) { return }
        Copy-Item $settings "$settings.bak" -Force
        $config.IntegratedWslDistros = @($config.IntegratedWslDistros | Where-Object { $_ -and $_ -ne $instanceName })
        $json = ($config | ConvertTo-Json -Depth 10) -replace "`r`n", "`n"
        [System.IO.File]::WriteAllText("$settings.tmp", $json, (New-Object System.Text.UTF8Encoding($false)))
        Move-Item "$settings.tmp" $settings -Force
    }

    hidden [string] DesktopSettingsPath() {
        if (-not $env:APPDATA) { return "" }
        return (Join-Path $env:APPDATA "Docker\settings-store.json")
    }
}
