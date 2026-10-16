using module ..\Entities\WslInstance.psm1
using module ..\Tools\Native.psm1

class WslRepository {

    hidden [string]$OrphanScript

    WslRepository([string]$distroDir) {
        $this.OrphanScript = Join-Path $distroDir "packs\cleanup_orphans.sh"
    }

    [WslInstance[]] GetAllDistros() {
        $found = @()
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss"
        if (-not (Test-Path $regPath)) { return $found }
        foreach ($key in Get-ChildItem $regPath) {
            $props = Get-ItemProperty $key.PSPath
            if (-not $props.DistributionName) { continue }
            $instance = [WslInstance]::new()
            try { $instance.SetName($props.DistributionName) } catch { continue }
            $found += $instance
        }
        return $found
    }

    [string] GetFolder([string]$distroName) {
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss"
        if (-not (Test-Path $regPath)) { return "" }
        foreach ($key in Get-ChildItem $regPath -ErrorAction SilentlyContinue) {
            $props = Get-ItemProperty $key.PSPath
            if ($props.DistributionName -ne $distroName) { continue }
            return ($props.BasePath -replace '^\\\\\?\\', '').TrimEnd('\')
        }
        return ""
    }

    [string[]] GetRunningNames() {
        $previousEAP = $global:ErrorActionPreference
        $global:ErrorActionPreference = "Continue"
        $names = (wsl.exe --list --quiet --running 2>$null) |
            ForEach-Object { ($_ -replace "`0", "").Trim() } |
            Where-Object { $_ }
        $global:ErrorActionPreference = $previousEAP
        return @($names)
    }

    [void] Import([string]$instanceName, [string]$folder, [string]$tarPath) {
        $arguments = '--import {0} "{1}" "{2}" --version 2' -f $instanceName, $folder, $tarPath
        $process = Start-Process wsl.exe -ArgumentList $arguments -NoNewWindow -PassThru
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) {
            throw "'$instanceName' could not be imported. (Exit code: $($process.ExitCode))"
        }
    }

    [void] Export([string]$instanceName, [string]$tarPath, [string]$format) {
        $arguments = '--export {0} "{1}" --format {2}' -f $instanceName, $tarPath, $format
        $process = Start-Process wsl.exe -ArgumentList $arguments -NoNewWindow -PassThru
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) {
            throw "'$instanceName' could not be exported. (Exit code: $($process.ExitCode))"
        }
    }

    [void] Unregister([string]$instanceName) {
        $arguments = '--unregister {0}' -f $instanceName
        $process = Start-Process wsl.exe -ArgumentList $arguments -NoNewWindow -PassThru
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) {
            throw "'$instanceName' could not be unregistered. (Exit code: $($process.ExitCode))"
        }
    }

    [void] Start([string]$instanceName) {
        Invoke-NativeCommand -Program "wsl.exe" -Arguments @("-d", $instanceName, "--exec", "/bin/true") -Message "'$instanceName' could not be started."
    }

    [void] Terminate([string]$instanceName) {
        Invoke-NativeCommand -Program "wsl.exe" -Arguments @("--terminate", $instanceName) -Message "'$instanceName' could not be stopped."
    }

    [void] TerminateQuietly([string]$instanceName) {
        $null = Test-NativeCommand -Program "wsl.exe" -Arguments @("--terminate", $instanceName)
        Start-Sleep -Seconds 1
    }

    [void] Compact([string]$instanceName) {
        Invoke-NativeCommand -Program "wsl.exe" -Arguments @("--manage", $instanceName, "--compact") -Message "The compact failed."
    }

    [void] OpenProfile([string]$instanceName) {
        Start-Sleep -Milliseconds 400
        $null = Start-Process wt.exe -ArgumentList ('-p "{0}"' -f $instanceName) -PassThru
    }

    [void] OpenBareShell([string]$instanceName) {
        $wsl = (Get-Command wsl.exe -CommandType Application -ErrorAction Stop | Select-Object -First 1).Path
        $null = Start-Process $wsl -ArgumentList ('-d {0} --cd ~' -f $instanceName) -PassThru
    }

    [int] RunInInstance([string]$instanceName, [string]$asUser, [string[]]$arguments, [string]$workingDirectory) {
        $wslArgs = @("-d", $instanceName)
        if ($asUser) { $wslArgs += @("-u", $asUser) }
        if ($workingDirectory) { $wslArgs += @("--cd", $workingDirectory) }
        $wslArgs += @("--") + $arguments

        $previousEAP = $global:ErrorActionPreference
        $global:ErrorActionPreference = "Continue"
        & wsl.exe @wslArgs
        $exitCode = $global:LASTEXITCODE
        $global:ErrorActionPreference = $previousEAP
        return $exitCode
    }

    [string[]] GetInInstance([string]$instanceName, [string[]]$arguments) {
        $previousEAP = $global:ErrorActionPreference
        $global:ErrorActionPreference = "Continue"
        $output = & wsl.exe -d $instanceName -- @arguments 2>$null
        $global:ErrorActionPreference = $previousEAP
        return @($output | ForEach-Object { ($_ -replace "`0", "").Trim() } | Where-Object { $_ })
    }

    [bool] TestInInstance([string]$instanceName, [string[]]$arguments) {
        $wslArgs = @("-d", $instanceName, "--") + $arguments
        return (Test-NativeCommand -Program "wsl.exe" -Arguments $wslArgs)
    }

    [string] GetHome([string]$instanceName) {
        return ($this.GetInInstance($instanceName, @("printenv", "HOME")) | Select-Object -First 1)
    }

    [string] GetFamily([string]$instanceName) {
        $release = @($this.GetInInstance($instanceName, @("cat", "/etc/os-release")))
        if ($release.Count -eq 0) { return "" }

        $fields = @{}
        foreach ($line in $release) {
            if ($line -match '^(ID|ID_LIKE)=(.*)$') {
                $fields[$Matches[1]] = $Matches[2].Trim('"').ToLower()
            }
        }
        if (-not $fields.ContainsKey("ID")) { return "" }

        $id = $fields["ID"]
        if ($id -ne "debian" -and $fields.ContainsKey("ID_LIKE") -and ($fields["ID_LIKE"] -split '\s+') -contains "debian") {
            return "debian"
        }
        return $id
    }

    [void] SaveOnboardingScript([string]$instanceName, [string]$source) {
        $throughTheDrives = "/mnt/" + $source.Substring(0, 1).ToLower() + ($source.Substring(2) -replace "\\", "/")
        $exitCode = $this.RunInInstance($instanceName, "root", @(
            "sh", "-c",
            "cp -f '$throughTheDrives' /root/onboarding.sh && chmod 755 /root/onboarding.sh && echo /root/onboarding.sh >> /root/.bashrc"
        ), "")
        if ($exitCode -ne 0) {
            throw "'$source' could not be placed in '$instanceName' as /root/onboarding.sh - are the Windows drives mounted in it?"
        }
    }

    [void] RunOnboarding([string]$instanceName, [string]$asUser) {
        $arguments = '-d {0} -u root env LANG=C /root/onboarding.sh {1}' -f $instanceName, $asUser
        $process = Start-Process wsl.exe -ArgumentList $arguments -NoNewWindow -PassThru
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) {
            throw "The onboarding.sh configuration script failed. (Exit code: $($process.ExitCode))"
        }
    }

    [string[]] GetInstalledPacks([string]$instanceName, [string]$packsDirectory) {
        $found = @($this.GetInInstance($instanceName, @("find", $packsDirectory, "-mindepth", "2", "-maxdepth", "2", "-name", "pack.conf")))
        $names = @()
        foreach ($line in $found) {
            $names += ($line -replace "/pack.conf$", "").Split("/")[-1]
        }
        return @($names | Sort-Object)
    }

    [int] CopyFolderIntoInstance([string]$instanceName, [string]$sourceFolder, [string]$target) {
        $code = $this.RunInInstance($instanceName, "", @("mkdir", "-p", $target), "")
        if ($code -ne 0) { return $code }

        $throughTheDrives = "/mnt/" + $sourceFolder.Substring(0, 1).ToLower() + ($sourceFolder.Substring(2) -replace "\\", "/")
        $drivesMounted = ($this.RunInInstance($instanceName, "", @("test", "-d", $throughTheDrives), "") -eq 0)

        $copied = $false
        if ($drivesMounted) {
            $copied = ($this.RunInInstance($instanceName, "", @("cp", "-r", ".", "$target/"), $sourceFolder) -eq 0)
        } else {
            $unc = "\\wsl.localhost\$instanceName" + ($target -replace "/", "\")
            try {
                Copy-Item -Path (Join-Path $sourceFolder "*") -Destination $unc -Recurse -Force -ErrorAction Stop
                $copied = $true
            } catch {
                $copied = $false
            }
        }

        if ($copied) {
            $null = $this.RunInInstance($instanceName, "", @("sh", "-c", "find '$target' -name '*.sh' -exec chmod +x {} +"), "")
            return 0
        }

        $null = $this.RemoveFolderInInstance($instanceName, $target)
        return 1
    }

    [int] CopyFileIntoInstance([string]$instanceName, [string]$sourceFile, [string]$targetPath) {
        $throughTheDrives = "/mnt/" + $sourceFile.Substring(0, 1).ToLower() + ($sourceFile.Substring(2) -replace "\\", "/")
        $drivesMounted = ($this.RunInInstance($instanceName, "", @("test", "-f", $throughTheDrives), "") -eq 0)

        if ($drivesMounted) {
            return $this.RunInInstance($instanceName, "", @("cp", "-f", $throughTheDrives, $targetPath), "")
        }

        $unc = "\\wsl.localhost\$instanceName" + ($targetPath -replace "/", "\")
        try {
            Copy-Item -LiteralPath $sourceFile -Destination $unc -Force -ErrorAction Stop
            return 0
        } catch {
            return 1
        }
    }

    [int] RunScriptInInstance([string]$instanceName, [string]$workingDirectory, [string]$script, [bool]$asRoot, [string]$errorLog) {
        $wslArgs = @("-d", $instanceName)
        if ($asRoot) {
            $userHome = $this.GetHome($instanceName)
            $wslArgs += @("-u", "root", "--cd", $workingDirectory, "--", "env", "LANG=C", "HOME=$userHome", "bash", $script)
        } else {
            $wslArgs += @("--cd", $workingDirectory, "--", "env", "LANG=C", "bash", $script)
        }

        $previousEAP = $global:ErrorActionPreference
        $global:ErrorActionPreference = "Continue"
        if ($errorLog) {
            & wsl.exe @wslArgs 2>&1 | Tee-Object -FilePath $errorLog -Append | Out-Host
        } else {
            & wsl.exe @wslArgs 2>&1 | Out-Host
        }
        $code = $global:LASTEXITCODE
        $global:ErrorActionPreference = $previousEAP
        return $code
    }

    [bool] HasInInstance([string]$instanceName, [string]$path) {
        return ($this.RunInInstance($instanceName, "", @("test", "-f", $path), "") -eq 0)
    }

    [int] RemoveFolderInInstance([string]$instanceName, [string]$target) {
        return ($this.RunInInstance($instanceName, "", @("rm", "-rf", $target), ""))
    }

    [bool] OpenPackSudoWindow([string]$instanceName) {
        $user = Split-Path -Leaf ($this.GetHome($instanceName))
        if (-not $user) { return $false }
        $command = "printf '%s`n' '$user ALL=(ALL) NOPASSWD: ALL' > /tmp/wsl-fleet-pack-sudo" +
            " && chmod 0440 /tmp/wsl-fleet-pack-sudo" +
            " && visudo -cf /tmp/wsl-fleet-pack-sudo > /dev/null" +
            " && mv /tmp/wsl-fleet-pack-sudo /etc/sudoers.d/90-wsl-fleet-packs"
        return ($this.RunInInstance($instanceName, "root", @("bash", "-c", $command), "") -eq 0)
    }

    [void] ClosePackSudoWindow([string]$instanceName) {
        $null = $this.RunInInstance($instanceName, "root", @("rm", "-f", "/etc/sudoers.d/90-wsl-fleet-packs"), "")
    }

    [bool] RunOrphanCleanup([string]$instanceName) {
        if (-not (Test-Path $this.OrphanScript)) { return $false }

        $remoteScript = "/tmp/cleanup_orphans.sh"
        $sent = $this.RunInInstance($instanceName, "", @("cp", "cleanup_orphans.sh", $remoteScript), (Split-Path $this.OrphanScript -Parent))
        if ($sent -ne 0) { return $false }

        $cleaned = $this.RunScriptInInstance($instanceName, "/tmp", "cleanup_orphans.sh", $true, "")
        $null = $this.RunInInstance($instanceName, "", @("rm", "-f", $remoteScript), "")
        return ($cleaned -eq 0)
    }
}
