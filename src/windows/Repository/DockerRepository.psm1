# ==============================================================================
# LE DÉPÔT DE DOCKER
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout ce qu'il a tiré
# lui-même.
using module ..\Tools\Native.psm1

# Le docker.exe et ses deux magasins : les images de la maison — construire,
# charger, exporter le rootfs, sauver, rendre, et le magasin sous assets — la
# porte du registre (l'API de Docker Hub, ou docker manifest), et Docker
# Desktop : son fichier, son redémarrage. Aucune règle ici : la machine, rien
# de plus. Le dossier des assets se tient à la construction.
class DockerRepository {
    hidden [string]$AssetsDir

    DockerRepository([string]$assetsDir) {
        $this.AssetsDir = $assetsDir
    }

    # La porte : une référence qui ne nomme aucun hôte (alpine:latest) est à
    # Docker Hub, et se demande par son API — le premier curl du PATH, celui
    # qu'un appel prendrait vraiment ; une qui nomme son hôte ou porte un
    # digest passe par docker manifest. Rend @{ Ok ; Why } — le pourquoi est
    # la phrase que le console montre.
    [hashtable] TestRegistryImage([string]$reference) {
        if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
            return @{ Ok = $false; Why = "docker is not on the PATH." }
        }

        # Seul le premier segment avant une barre peut nommer un hôte, et seul
        # un segment portant un point ou deux-points, ou lisant localhost, le
        # fait : dans alpine:latest aucun hôte n'est nommé, le deux-points est
        # celui du tag.
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
            $answer = @(& $curl.Path -s -o NUL -w "%{http_code}" -I $url 2>&1)
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

        # La première chose que docker a dite — "no such manifest: ...",
        # "denied", ou la plainte du démon ; un canal vide retombe sur le
        # code.
        $why = ""
        foreach ($line in $output) {
            if ("$line") { $why = "$line"; break }
        }
        if (-not $why) { $why = "docker exited with code $code." }
        return @{ Ok = $false; Why = $why }
    }

    # L'image construite : un processus à lui — un docker build est des
    # minutes de sortie qu'il faut voir.
    [void] Build([string]$tag, [string]$dockerfile, [string]$context) {
        $arguments = 'build -t {0} -f "{1}" "{2}"' -f $tag, $dockerfile, $context
        $process = Start-Process docker -ArgumentList $arguments -NoNewWindow -PassThru
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) {
            throw "Docker build failed. (Exit code: $($process.ExitCode))"
        }
    }

    # L'image montée, chargée — docker load dit ce qu'il a posé : "Loaded
    # image: name:tag" pour une image sauvegardée taguée, "Loaded image ID:"
    # pour une image sauvegardée par id. Rend ce nom-là, jamais un second
    # posé dessus.
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

    # L'image, en tar de système de fichiers qu'on peut importer : un
    # conteneur jetable dans l'image, exporté, retiré. Le conteneur est au
    # build ; l'image n'est pas touchée.
    [void] ExportRootfs([string]$imageName, [string]$outputPath) {
        $container = "wsl-temp-export-$([guid]::NewGuid().ToString().Substring(0, 8))"
        try {
            # L'id du conteneur tombe sur stdout et ne dit rien ici ; le reste
            # parle.
            Invoke-NativeCommand -Program "docker" -Arguments @("create", "--name", $container, $imageName) -Message "Docker could not create a container from '$imageName' (its own words are above)."
            Invoke-NativeCommand -Program "docker" -Arguments @("export", "-o", $outputPath, $container) -Message "Docker export failed."
        } finally {
            # Au mieux, et rien ici ne doit lever : le finally court aussi sur
            # un échec, et une erreur d'ici enterrerait le message au-dessus.
            $null = Test-NativeCommand -Program "docker" -Arguments @("rm", "-f", $container)
        }
    }

    # L'image de travail écrite en fichier — le tar que la route image
    # recharge, pour qu'une image revienne en secondes au lieu d'un rebuild.
    # Le dossier d'abord : une sauvegarde dans un dossier absent échouerait
    # pour une raison qui n'est pas celle de l'image. Faux quand docker a
    # refusé — docker save -o ne dit rien d'autre.
    [bool] SaveImage([string]$tag, [string]$outputPath) {
        $folder = Split-Path $outputPath -Parent
        if (-not (Test-Path $folder)) { $null = New-Item -ItemType Directory -Path $folder -Force }
        return (Test-NativeCommand -Program "docker" -Arguments @("save", "-o", $outputPath, $tag))
    }

    # Le tag repris du magasin local — l'image sous son propre nom laissée
    # tranquille. Vrai quand c'est fait.
    [bool] RemoveImage([string]$tag) {
        return (Test-NativeCommand -Program "docker" -Arguments @("rmi", "-f", $tag))
    }

    # Docker Desktop redémarré — la liste des distros n'est relue qu'à son
    # démarrage. Faux quand le redémarrage a échoué : le nom est écrit, Docker
    # le verra au prochain — l'appelant décide si c'est grave.
    [bool] RestartDesktop() {
        return (Test-NativeCommand -Program "docker" -Arguments @("desktop", "restart"))
    }

    # Docker Desktop lancé — l'installeur à son chemin habituel, la ligne de
    # commande en repli. Faux quand ni l'un ni l'autre n'a pu.
    [bool] StartDesktop() {
        try {
            Start-Process (Join-Path $env:ProgramFiles "Docker\Docker\Docker Desktop.exe") -ErrorAction Stop
            return $true
        } catch {
            return (Test-NativeCommand -Program "docker" -Arguments @("desktop", "start"))
        }
    }

    # Docker répond-il — la sonde qui précède la fenêtre de naissance
    # (docker info). Un docker absent, ou muet, est un non : pas une erreur.
    [bool] TestRunning() {
        try {
            return (Test-NativeCommand -Program "docker" -Arguments @("info"))
        } catch {
            return $false
        }
    }

    # Le siège d'une image gardée : le tar sous assets\dockerimages\<nom>\ —
    # l'emplacement par le nom, comme les dossiers d'instances.
    [string] GetSavedImagePath([string]$name) {
        return (Join-Path $this.AssetsDir "dockerimages\$name\$name.tar")
    }

    # Le magasin de la maison : chaque dossier sous assets\dockerimages qui
    # porte un fichier, en ligne — le nom du fichier, son chemin, sa date. Un
    # dossier vide n'est pas une image.
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

    # Les noms que Docker Desktop connaît, lus d'un coup — une lecture pour
    # toutes les lignes d'un index. $null quand la réponse est « inconnue »
    # (pas de fichier, fichier illisible) : ce n'est pas la même réponse que
    # « aucun ».
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

    # Ce que Docker Desktop sait d'une distribution : "yes", "no", ou
    # "unknown" — pas installé, ou illisible. Un "unknown" n'est pas un "no"
    # et se rapporte pour ce qu'il est.
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

    # Le nom écrit chez Docker Desktop — la sauvegarde à côté, le nom rebâti
    # plutôt qu'ajouté deux fois, et l'écriture sans BOM : ce fichier, écrit
    # par Docker Desktop, n'en porte pas.
    [void] SetDesktopState([string]$instanceName) {
        $settings = $this.DesktopSettingsPath()
        $config = Get-Content $settings -Raw | ConvertFrom-Json
        Copy-Item $settings "$settings.bak" -Force
        $config.IntegratedWslDistros = @($config.IntegratedWslDistros | Where-Object { $_ -and $_ -ne $instanceName }) + $instanceName
        $json = ($config | ConvertTo-Json -Depth 10) -replace "`r`n", "`n"
        [System.IO.File]::WriteAllText("$settings.tmp", $json, (New-Object System.Text.UTF8Encoding($false)))
        Move-Item "$settings.tmp" $settings -Force
    }

    # Le nom ôté de Docker Desktop, au départ de l'instance — le même ménage
    # que la pose, en sens inverse. Un nom qui n'y est pas : rien à faire.
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

    # --- les pas partagés -------------------------------------------------------

    hidden [string] DesktopSettingsPath() {
        # Sans %APPDATA% (les bacs à sable de certaines suites), il n'y a pas
        # de fichier à viser : vide.
        if (-not $env:APPDATA) { return "" }
        return (Join-Path $env:APPDATA "Docker\settings-store.json")
    }
}
