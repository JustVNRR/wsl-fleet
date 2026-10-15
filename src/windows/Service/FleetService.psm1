# ==============================================================================
# LA FLOTTE — LE SERVICE
# ==============================================================================
# Ce dont ce fichier nomme, déclaré ici : un module résout un type qu'il a tiré
# lui-même.
using module ..\Repository\ConfigRepository.psm1
using module ..\Repository\WslRepository.psm1
using module ..\Repository\InstanceRepository.psm1
using module ..\Repository\ArchiveRepository.psm1
using module .\InstanceService.psm1
using module ..\Dto\InstanceDto.psm1
using module ..\Tools\Helpers.psm1

# La racine : elle se dit, et elle se déplace. Trois méthodes, et aucun Dto —
# un seul champ se passe nu : la racine se rend nue, la destination se donne
# nue, la flotte se rend par ses noms. La règle de GetRoot : root.txt lu ;
# quand il manque ou que son dossier a disparu, le seul foyer de nos instances
# gagne, sinon D:\WSL, sinon le profil ; sans rien, elle jette — deux foyers,
# c'est ainsi que les données semblent perdues.
class FleetService {
    hidden [ConfigRepository]$Config
    hidden [WslRepository]$Wsl
    hidden [InstanceRepository]$Instances
    hidden [ArchiveRepository]$Archives
    hidden [InstanceService]$InstanceService

    FleetService([ConfigRepository]$config, [WslRepository]$wsl,
                 [InstanceRepository]$instances, [ArchiveRepository]$archives,
                 [InstanceService]$instanceService) {
        $this.Config = $config
        $this.Wsl = $wsl
        $this.Instances = $instances
        $this.Archives = $archives
        $this.InstanceService = $instanceService
    }

    # La racine que la flotte habite : celle que le fichier garde et qui vit
    # encore ; sinon la décision — le seul foyer de nos instances quand il n'y
    # en a qu'un, D:\WSL quand D: existe, le profil sinon — écrite pour les
    # prochaines courses. Une racine mémorisée disparue n'est jamais
    # silencieusement remplacée : quand les instances vivent encore sous un
    # seul dossier, c'est lui qui reprend la main ; sans nulle part où
    # pointer, elle jette.
    [string] GetRoot() {
        $saved = $this.Config.GetSavedRoot()
        if ($saved -and (Test-Path $saved)) { return $saved }

        $homes = @($this.RootHomes())

        if (-not $saved) {
            $decided = ""
            if ($homes.Count -eq 1) { $decided = $homes[0] }
            elseif (Test-Path "D:\") { $decided = "D:\WSL" }
            else { $decided = "$env:USERPROFILE\WSL" }
            $this.Config.SaveRoot($decided)
            return $decided
        }

        if ($homes.Count -eq 1) {
            $this.Config.SaveRoot($homes[0])
            return $homes[0]
        }

        throw "The working folder '$saved' is gone, and no existing folder holds your instances."
    }

    # Le migrate, la part de la flotte : le dossier d'arrivée fait prêt (un
    # chemin impossible jette avant que rien ne bouge), le dossier des
    # archives déplacé — un renommage sur un volume, robocopy à travers,
    # après la place — puis la racine réécrite. Un déplacement raté laisse la
    # racine où elle était. Les instances, elles, s'archivent puis se
    # désenregistrent une par une dans Migrate (InstanceService.Remove,
    # l'archivage d'abord) — SetRoot ne fait ici que ce qui est à lui.
    [string] SetRoot([string]$target) {
        # La garde, ici aussi : SetRoot est une porte à part, et un « effef »
        # y ferait le même dégât.
        $problem = Test-FleetTarget $target
        if ($problem) { throw $problem }
        $this.Instances.EnsureFolder($target)
        $this.Archives.MoveTo($target)
        $this.Config.SaveRoot($target)
        return $target
    }

    # La racine redite : la flotte ET le service des instances qu'elle tient
    # suivent — l'entrée re-root ce qu'elle a bâti de son côté avec la même
    # racine.
    [void] ReRoot([string]$root) {
        $this.Instances.ReRoot($root)
        $this.Archives.ReRoot($root)
        $this.InstanceService.ReRoot($root)
    }

    # La flotte de chez nous, sous la racine : les inscrites dont le dossier
    # vit là — inscrites au registre, notre marque à l'appui, le parent du
    # dossier étant la racine — par leurs noms, triés. C'est ce que le
    # migrate archive et désinscrit une par une, au contrôleur ; une inscrite
    # d'ailleurs n'en est pas — son disque n'est pas à nous.
    [string[]] GetFleet() {
        $root = $this.GetRoot()
        $names = @()
        foreach ($distro in @($this.Wsl.GetAllDistros())) {
            $folder = $this.Wsl.GetFolder($distro.GetName())
            if (-not $folder -or -not (Test-Path $folder)) { continue }
            if (-not $this.Instances.HasMarkerIn($folder)) { continue }
            if ((Split-Path -Path $folder -Parent).TrimEnd('\') -ne $root.TrimEnd('\')) { continue }
            $names += $distro.GetName()
        }
        return @($names | Sort-Object)
    }

    # Le voyage entier : la flotte de chez nous archivée et désinscrite UNE
    # PAR UNE — l'espace se libère au fur et à mesure, le disque ne double
    # jamais —, puis la part de la flotte (SetRoot : le dossier d'arrivée
    # fait prêt, les archives qui voyagent, la racine réécrite). Un échec
    # arrête là : ce qui est déjà archivé et désinscrit l'est, et la course
    # suivante reprend avec le reste. Le registre n'est jamais touché
    # autrement que par ces désinscriptions. Rend les noms emportés.
    # -------------------------------------------------------------------------
    # Le fichier des réglages Windows
    # -------------------------------------------------------------------------

    # Le ~/.wslconfig : son gabarit écrit quand il manque — un fichier à
    # quelqu'un n'est jamais touché — puis ouvert, l'éditeur par défaut, et
    # son chemin rendu, la naissance comprise.
    [object] WslConfig() {
        $path = Join-Path $env:USERPROFILE ".wslconfig"
        $created = -not (Test-Path $path)
        $path = $this.Config.EnsureWslConfig()
        Start-Process -FilePath $path
        return [PSCustomObject]@{ Path = $path; Created = $created }
    }

    [MigrateResponseDto] Migrate([string]$target) {
        # La destination d'ABORD — le premier désenregistrement attend. Vécu :
        # un « effef » relatif avait tout archivé, tout désinscrit et tout
        # déplacé pour mourir au dernier contrôle ; ici, un refus ne coûte
        # rien.
        $problem = Test-FleetTarget $target
        if ($problem) { throw $problem }
        $response = [MigrateResponseDto]::new()
        $moved = @()
        foreach ($name in @($this.GetFleet())) {
            $dto = [RemoveDto]::new()
            $dto.InstanceName = $name
            $dto.ArchiveFirst = $true
            $this.InstanceService.Remove($dto)
            $moved += $name
        }
        $response.Moved = @($moved)
        $response.Target = $this.SetRoot($target)
        return $response
    }

    # Où nos instances disent habiter : les parents de nos inscrites dont le
    # dossier vit encore — un dossier sur un disque disparu n'a pas voix —
    # réduits aux distincts. Un seul répond la maison ; aucun ou plusieurs ne
    # disent rien.
    hidden [string[]] RootHomes() {
        $homes = @()
        foreach ($distro in @($this.Wsl.GetAllDistros())) {
            $folder = $this.Wsl.GetFolder($distro.GetName())
            if (-not $folder -or -not (Test-Path $folder)) { continue }
            if (-not $this.Instances.HasMarkerIn($folder)) { continue }
            $parent = Split-Path -Path $folder -Parent
            if ($homes -notcontains $parent) { $homes += $parent }
        }
        return @($homes)
    }
}
