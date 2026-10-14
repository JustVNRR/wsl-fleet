# ==============================================================================
# LE DÉPÔT DE WSL
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout un type qu'il a tiré
# lui-même.
using module ..\Model\WslInstance.psm1
using module ..\Tools\Native.psm1

# Tout ce qui parle à wsl.exe, et le registre des distributions : le listage
# (le registre, et qui tourne — et le dossier qu'une inscrite habite), l'import,
# l'export, le désenregistrement, la vie (départ, arrêt, compacité), les
# fenêtres (le profil, la console nue), la lecture dans l'instance (le home, la
# famille), le premier démarrage, et les gestes des packs DANS l'instance — la
# copie du dossier, les scripts, la porte sudo, le ménage des orphelins. Les
# points de lancement qui portent LANG=C le portent ici, dans leur ligne — les
# scripts de packs, le premier démarrage. Aucune règle ici : la machine, rien
# de plus. Le dossier des sources (src\distro) se tient à la construction : le
# script de ménage des orphelins est le dépôt, jamais copié.
class WslRepository {
    hidden [string]$OrphanScript

    WslRepository([string]$distroDir) {
        $this.OrphanScript = Join-Path $distroDir "packs\cleanup_orphans.sh"
    }

    # =========================================================================
    # LE REGISTRE
    # =========================================================================

    # Ce que Windows connaît : le registre des distributions — leur nom seul.
    # Un nom que la classe refuse (une inscription à la main, venue de nulle
    # part) est laissé dehors : la règle vit sur la classe, et cette liste ne
    # porte que ce qu'elle accepte.
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

    # Le dossier qu'une inscrite habite, demandé au registre — la racine se
    # résout par le nom pour les nôtres, mais le registre seul sait où une
    # inscrite est vraiment (la règle de la racine a besoin de le demander).
    # Vide quand rien ne porte ce nom.
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

    # Qui tourne, demandé à WSL — le registre ne le dit pas. Le nom nul que
    # wsl.exe glisse dans sa sortie est retiré.
    [string[]] GetRunningNames() {
        $previousEAP = $global:ErrorActionPreference
        $global:ErrorActionPreference = "Continue"
        $names = (wsl.exe --list --quiet --running 2>$null) |
            ForEach-Object { ($_ -replace "`0", "").Trim() } |
            Where-Object { $_ }
        $global:ErrorActionPreference = $previousEAP
        return @($names)
    }

    # =========================================================================
    # L'IMPORT, L'EXPORT, LE DÉSENREGISTREMENT
    # =========================================================================

    # L'import, à la naissance : le tar posé dans un dossier, la distribution
    # enregistrée. Version 2 — les nôtres le sont toutes.
    [void] Import([string]$instanceName, [string]$folder, [string]$tarPath) {
        $arguments = '--import {0} "{1}" "{2}" --version 2' -f $instanceName, $folder, $tarPath
        $process = Start-Process wsl.exe -ArgumentList $arguments -NoNewWindow -PassThru
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) {
            throw "'$instanceName' could not be imported. (Exit code: $($process.ExitCode))"
        }
    }

    # L'export, à l'archivage : la distribution écrite en tar, au format que
    # l'appelant nomme (l'archivage prend le sien, la copie le sien).
    [void] Export([string]$instanceName, [string]$tarPath, [string]$format) {
        $arguments = '--export {0} "{1}" --format {2}' -f $instanceName, $tarPath, $format
        $process = Start-Process wsl.exe -ArgumentList $arguments -NoNewWindow -PassThru
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) {
            throw "'$instanceName' could not be exported. (Exit code: $($process.ExitCode))"
        }
    }

    # Le désenregistrement, à la destruction : WSL l'oublie.
    [void] Unregister([string]$instanceName) {
        $arguments = '--unregister {0}' -f $instanceName
        $process = Start-Process wsl.exe -ArgumentList $arguments -NoNewWindow -PassThru
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) {
            throw "'$instanceName' could not be unregistered. (Exit code: $($process.ExitCode))"
        }
    }

    # =========================================================================
    # LA VIE
    # =========================================================================

    # Le départ : --exec lance une commande et revient — la distribution se
    # lève sans ouvrir de shell.
    [void] Start([string]$instanceName) {
        Invoke-NativeCommand -Program "wsl.exe" -Arguments @("-d", $instanceName, "--exec", "/bin/true") -Message "'$instanceName' could not be started."
    }

    # L'arrêt : WSL termine la distribution.
    [void] Terminate([string]$instanceName) {
        Invoke-NativeCommand -Program "wsl.exe" -Arguments @("--terminate", $instanceName) -Message "'$instanceName' could not be stopped."
    }

    # L'arrêt dont l'échec EST ignoré — une distribution à moitié partie ne
    # doit pas bloquer sa propre destruction — suivi de la pause que la
    # commande prenait toujours : un --unregister juste après courrait trop tôt.
    [void] TerminateQuietly([string]$instanceName) {
        $null = Test-NativeCommand -Program "wsl.exe" -Arguments @("--terminate", $instanceName)
        Start-Sleep -Seconds 1
    }

    # La compacité, en place : WSL reprend ce que le disque garde. Refuse de
    # lui-même quand le disque ne se compacte pas.
    [void] Compact([string]$instanceName) {
        Invoke-NativeCommand -Program "wsl.exe" -Arguments @("--manage", $instanceName, "--compact") -Message "The compact failed."
    }

    # =========================================================================
    # LES FENÊTRES
    # =========================================================================

    # La fenêtre du profil : Terminal l'ouvre sous le nom que WSL a enregistré
    # — le nom y entre entre guillemets, wt.exe les enlève. Le service touche
    # le settings avant d'appeler (un fragment posé après la dernière touche
    # ne serait pas encore résolu) ; la pause laisse la relecture finir avant
    # que la fenêtre demande le profil.
    [void] OpenProfile([string]$instanceName) {
        Start-Sleep -Milliseconds 400
        $null = Start-Process wt.exe -ArgumentList ('-p "{0}"' -f $instanceName) -PassThru
    }

    # La console nue — le repli, et l'honnête quand aucun profil ne répond.
    # Le nom entre sans guillemets : wsl.exe analyse sa propre ligne et ne les
    # retire pas, un nom cité cesse de correspondre ; le ~ voyage dans la
    # chaîne, où rien ne l'étend.
    [void] OpenBareShell([string]$instanceName) {
        $null = Start-Process wsl.exe -ArgumentList ('-d {0} --cd ~' -f $instanceName) -PassThru
    }

    # =========================================================================
    # LA LECTURE DANS L'INSTANCE
    # =========================================================================

    # Une commande lancée dans l'instance, sa sortie qui coule — les installs
    # de packs, ce qu'on doit voir. Le code de sortie revient : l'appelant
    # décide. Le dossier de travail se dit quand l'appel en a un (la copie du
    # pack se fait depuis le dossier de la source).
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

    # Une commande lancée dans l'instance, sa sortie lue — une entrée par
    # ligne, le nom nul retiré.
    [string[]] GetInInstance([string]$instanceName, [string[]]$arguments) {
        $previousEAP = $global:ErrorActionPreference
        $global:ErrorActionPreference = "Continue"
        $output = & wsl.exe -d $instanceName -- @arguments 2>$null
        $global:ErrorActionPreference = $previousEAP
        return @($output | ForEach-Object { ($_ -replace "`0", "").Trim() } | Where-Object { $_ })
    }

    # Une commande lancée dans l'instance quand le code est la seule réponse —
    # « docker répond-il ? », « le script est-il là ? ». Rien ne parle.
    [bool] TestInInstance([string]$instanceName, [string[]]$arguments) {
        $wslArgs = @("-d", $instanceName, "--") + $arguments
        return (Test-NativeCommand -Program "wsl.exe" -Arguments $wslArgs)
    }

    # Le home de l'instance, demandé plutôt que deviné : ~ ne s'étend que dans
    # un shell, et la lecture évite les shells exprès.
    [string] GetHome([string]$instanceName) {
        return ($this.GetInInstance($instanceName, @("printenv", "HOME")) | Select-Object -First 1)
    }

    # La famille de la distribution, lue dans son propre /etc/os-release :
    # l'ID, plié sur la famille dont elle est quand c'est un dérivé — Ubuntu
    # et Linux Mint répondent "debian", et l'apt sous eux est celui de la
    # famille. Une machine qui ne sait pas dire (pas de fichier, pas d'ID)
    # répond vide, et vide ne filtre rien.
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

    # =========================================================================
    # LE PREMIER DÉMARRAGE
    # =========================================================================

    # L'onboarding posé dans la distribution, avant que le compte n'existe :
    # un shell, trois gestes, dans cet ordre — la copie, le droit
    # d'exécution, la ligne du .bashrc en dernier ; un shell root ouvert
    # entre-temps ne doit pas lancer un onboarding qui n'est pas encore
    # entier. Les chemins D:\... deviennent /mnt/d/... : la route des packs.
    [void] SaveFirstBootScript([string]$instanceName, [string]$source) {
        $throughTheDrives = "/mnt/" + $source.Substring(0, 1).ToLower() + ($source.Substring(2) -replace "\\", "/")
        $exitCode = $this.RunInInstance($instanceName, "root", @(
            "sh", "-c",
            "cp -f '$throughTheDrives' /root/onboarding.sh && chmod 755 /root/onboarding.sh && echo /root/onboarding.sh >> /root/.bashrc"
        ), "")
        if ($exitCode -ne 0) {
            throw "'$source' could not be placed in '$instanceName' as /root/onboarding.sh - are the Windows drives mounted in it?"
        }
    }

    # L'onboarding joué, en root, le nom du compte pour unique argument. Un
    # processus à lui, la route du shell : un natif sous une méthode de classe
    # a sa sortie avalée (mesuré), et l'onboarding est un script qu'il faut
    # VOIR et auquel il faut RÉPONDRE. WaitForExit, pas -Wait : -Wait
    # attendrait aussi l'aide de WSL qu'une session laisse derrière. env
    # LANG=C pour la raison des scripts de packs : WSL tend la locale de
    # Windows, et l'onboarding installe ses propres outils dessous.
    [void] RunFirstBoot([string]$instanceName, [string]$asUser) {
        $arguments = '-d {0} -u root env LANG=C /root/onboarding.sh {1}' -f $instanceName, $asUser
        $process = Start-Process wsl.exe -ArgumentList $arguments -NoNewWindow -PassThru
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) {
            throw "The onboarding.sh configuration script failed. (Exit code: $($process.ExitCode))"
        }
    }

    # =========================================================================
    # LES PACKS, DANS L'INSTANCE
    # =========================================================================

    # Ce que l'instance porte : chaque dossier sous ~/.config/packs qui tient
    # un pack.conf, par son nom — trié, la fenêtre numérote ces listes.
    [string[]] GetInstalledPacks([string]$instanceName, [string]$packsDirectory) {
        $found = @($this.GetInInstance($instanceName, @("find", $packsDirectory, "-mindepth", "2", "-maxdepth", "2", "-name", "pack.conf")))
        $names = @()
        foreach ($line in $found) {
            $names += ($line -replace "/pack.conf$", "").Split("/")[-1]
        }
        return @($names | Sort-Object)
    }

    # Le dossier du pack copié dans l'instance — la copie, la mise à
    # l'exécutable, et rien de plus. Deux routes, décidées en demandant à
    # l'instance : par les disques montés quand ils sont là (le dossier de la
    # source en dossier de travail, `.` seul à nommer), sinon par le partage
    # de Windows (\\wsl.localhost\<distro>), qui n'a besoin d'aucun disque.
    # Rend le code de la copie — zéro quand c'est fait ; l'échec a retiré le
    # dossier vide, qui ferait passer le pack pour installé.
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
            # Les globs voyagent entre guillemets simples dans un sh -c : nus,
            # ils sont à la merci de la façon dont wsl.exe tend la commande, et
            # l'une d'elles les développe — là où rien ne correspond, le shell
            # s'arrête, et le pack arrive avec chaque script inexécutable.
            $null = $this.RunInInstance($instanceName, "", @("sh", "-c", "find '$target' -name '*.sh' -exec chmod +x {} +"), "")
            return 0
        }

        $null = $this.RemoveFolderInInstance($instanceName, $target)
        return 1
    }

    # Un script du pack, lancé depuis son propre dossier. La sortie coule — le
    # dossier est mis à l'exécutable et rien de plus — et l'écran la voit :
    # un install dure des minutes. env LANG=C : WSL tend la locale de Windows,
    # et une machine qui ne l'a jamais générée fait jurer perl sous chaque
    # apt. En root, le home de l'utilisateur en HOME : ce que le script pose
    # reste à lui. Le canal d'erreur va aussi au journal quand un chemin est
    # donné — c'est là que la naissance lit le pourquoi d'un échec.
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

    # Le script est-il là ? Demandé avant toute promesse : un pack installé
    # avant que les packs n'aient un remove.sh est un pack dont le dossier
    # peut partir, mais rien ne sera défait côté système.
    [bool] HasInInstance([string]$instanceName, [string]$path) {
        return ($this.RunInInstance($instanceName, "", @("test", "-f", $path), "") -eq 0)
    }

    # Le dossier du pack retiré de l'instance.
    [int] RemoveFolderInInstance([string]$instanceName, [string]$target) {
        return ($this.RunInInstance($instanceName, "", @("rm", "-rf", $target), ""))
    }

    # La porte sans mot de passe, ouverte pour une installation : WSL se fie à
    # son côté Windows pour root sans mot de passe (wsl -u root), et les
    # scripts install.sh tournent comme l'utilisateur de l'instance — leurs
    # fichiers doivent être à lui. Écrite par le propre contrôle de visudo,
    # jamais à côté : une règle cassée dans /etc/sudoers.d casse sudo lui-même.
    # Rien n'en reste une fois la course finie.
    [bool] OpenPackSudoWindow([string]$instanceName) {
        $user = Split-Path -Leaf ($this.GetHome($instanceName))
        if (-not $user) { return $false }
        $command = "printf '%s`n' '$user ALL=(ALL) NOPASSWD: ALL' > /tmp/wsl-stack-pack-sudo" +
            " && chmod 0440 /tmp/wsl-stack-pack-sudo" +
            " && visudo -cf /tmp/wsl-stack-pack-sudo > /dev/null" +
            " && mv /tmp/wsl-stack-pack-sudo /etc/sudoers.d/90-wsl-stack-packs"
        return ($this.RunInInstance($instanceName, "root", @("bash", "-c", $command), "") -eq 0)
    }

    [void] ClosePackSudoWindow([string]$instanceName) {
        $null = $this.RunInInstance($instanceName, "root", @("rm", "-f", "/etc/sudoers.d/90-wsl-stack-packs"), "")
    }

    # Ce que les retraits ont laissé sur le système : les dépendances que
    # personne ne revendique. Le script demande à apt et ldd, et ne retire
    # qu'après ; il voyage comme un pack — une copie, un chemin nu, jamais son
    # texte. Faux quand il n'y a rien à lancer.
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
