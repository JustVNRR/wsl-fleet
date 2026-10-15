# ==============================================================================
# LES DTO DE L'INSTANCESERVICE, TOUS
# ==============================================================================
# La règle : méthode Xxx → XxxDto en entrée, XxxResponseDto en retour — quand
# il y a quelque chose à porter : sans paramètre, pas de Dto ; sans retour,
# pas de ResponseDto ; un seul champ, pas de classe — le bool ou la chaîne se
# passent nus ; une classe à partir de deux champs. Chaque Dto ne sert qu'à
# sa méthode — et un Dto ne porte que des Dto : jamais une classe du Modèle
# dans ses membres, on passe le nom et le service résout. La ligne du pack
# (WslPackDto) vit avec les Dto du PackCatalogService.
using module .\PackCatalogDto.psm1

# --- l'index et ses lectures --------------------------------------------------

# La ligne de l'index : ce qu'on affiche d'une instance — son nom, sa taille,
# si c'est une archive, et l'état Docker Desktop (yes/no/unknown, lu frais à
# GetAll : la fenêtre saura quel bouton offrir — register ou unregister).
# L'archive ne porte rien : rien ne se propose pour elle. GetAll en rend la
# liste, GetByName en rend une.
class WslIndexDto {
    [string]$Name
    [long]$Size
    [bool]$IsArchive
    [string]$Docker
    # Le dossier de la ligne, et — pour une archive — la date que les listes
    # montrent, déjà mise en forme.
    [string]$Path = ""
    [string]$Archived = ""
}

# La ligne d'un orphelin : un dossier marqué que personne ne revendique — ce
# qu'une suppression interrompue, ou un wsl --unregister venu d'ailleurs,
# laisse derrière. Nom, dossier, taille : aucune commande ne le retire, une
# main le fait — le dossier est là pour qu'elle le trouve. GetOrphans en rend
# la liste.
class WslOrphanDto {
    [string]$Name
    [string]$Path
    [long]$Size
}

# --- la naissance et la vie ---------------------------------------------------

# Une source de naissance : une ligne des listes du build — le nom tel que
# l'écran l'affiche (le nom du dossier sans son hash final, la date du fichier
# entre parenthèses) et le chemin que le choix rend. Family : ce que le
# premier FROM d'un Dockerfile dit (le repli des dérivées de Debian compris)
# — vide pour un onboarding, dont la famille n'a pas de sens.
class WslBuildSourceDto {
    [string]$Name
    [string]$Path
    [string]$Family
    # Téléversée (l'empreinte au nom de l'emplacement) — la corbeille ne
    # touche qu'à celles-là ; une recette du dépôt se retire à la main.
    [bool]$Uploaded
}

# Une ligne de la checklist des packs, à la naissance : le nom, la famille,
# la description, et la marque du socle (oh_my_shell — la case pré-cochée
# quand la famille de la source se lit et colle). GetBuildPacks les rend
# toutes, offertes ; le filtre par famille se fait sur la ligne.
class WslBuildPackDto {
    [string]$Name
    [string]$Family
    [string]$Description
    [bool]$Shell
}

# Ce depuis quoi on construit : les Dockerfiles et les onboardings présents
# sous les assets. GetBuildSources en rend les deux listes.
class GetBuildSourcesResponseDto {
    [WslBuildSourceDto[]]$Dockerfiles = @()
    [WslBuildSourceDto[]]$Onboardings = @()
    [WslBuildSourceDto[]]$Recipes = @()
}

# Une recette téléversée : quoi (le dossier des recettes), d'où vient le
# fichier choisi, et sous quel nom dedans (Dockerfile, onboarding.sh, le tar
# tel quel). UploadRecipe rend la ligne — nom d'écran, chemin, famille —
# prête à poser dans la liste de la fenêtre.
# The + button's payload: the name a fresh recipe folder is created under.
class NewRecipeDto {
    [string]$Name
}

class UploadRecipeDto {
    [string]$Kind
    [string]$Source
    [string]$FileName
}

# Une recette rendue où l'utilisateur pointe : la source, et la cible.
class ExportRecipeDto {
    [string]$Path
    [string]$Target
}

# Le voyage rendu : les instances emportées, et la cible où la flotte vit
# maintenant.
class MigrateResponseDto {
    [string[]]$Moved = @()
    [string]$Target
}

# Le dessin d'une icône : les lettres et les trois couleurs.
class WslIconDto {
    [string]$Text
    [string]$Top
    [string]$Bottom
    [string]$TextColor
}

# La route d'une naissance — elle voyage avec son Dto.
enum WslBuildType {
    Dockerfile
    Image
    Registry
    Recipe
}

# La tambouille de la naissance : tout ce qu'il faut pour construire, rien du
# résultat — l'instance ne la garde pas. L'apparence arrive en clair (police,
# couleurs, dessin), les packs par leurs noms.
class BuildDto {
    [string]$Name
    [string]$User
    [WslBuildType]$BuildType
    [string]$BuildPath
    [string]$Context
    [string]$Onboarding
    [string]$Font
    [string]$ColourScheme
    [WslIconDto]$Icon
    [string[]]$Packs = @()
    [bool]$KeepImage = $true
    [bool]$RegisterDocker = $false
}

# Le verdict de la naissance : un instantané du making, pas de l'instance.
enum WslRecipeStatus {
    Ok
    Warning
    Nok
}

# Ce que la naissance rend : le nom de l'instance créée et le verdict, avec
# ses lignes.
class BuildResponseDto {
    [string]$InstanceName
    [WslRecipeStatus]$Status
    [string[]]$Messages = @()
}

# ArchiveFirst : le oui de la porte — un archivage d'abord, la destruction
# ensuite.
class RemoveDto {
    [string]$InstanceName
    [bool]$ArchiveFirst = $false
}

# ArchiveFirst : le oui de la porte — un archivage d'abord, la compacité
# ensuite.
class CompactDto {
    [string]$InstanceName
    [bool]$ArchiveFirst = $false
}

# Le nom de l'instance relue, si l'archivage d'abord a eu lieu — et les
# tailles, mesurées par le service : avant la compaction, après, et la gagnée
# (l'écart, zéro quand le disque n'avait rien à rendre).
class CompactResponseDto {
    [string]$InstanceName
    [bool]$Archived
    [bool]$Restarted
    [long]$SizeBefore
    [long]$SizeAfter
    [long]$Gained
}

# --- le look ------------------------------------------------------------------

# Ce que l'instance porte : sa police, ses couleurs, le dessin de son icône —
# et si notre fragment Terminal est en place.
class GetAppearanceResponseDto {
    [string]$Font
    [string]$ColourScheme
    [WslIconDto]$Icon
    [bool]$HasFragment
    # Le siège de l'icône quand une image y est posée — la fenêtre du look
    # montre le fichier en place (vide : rien qu'un dessin).
    [string]$IconPath
}

# Les changements demandés, chacun facultatif — vide = non touché. Une image
# prend le siège de l'icône (le dessin reste derrière) ; le dessin, lui, se
# donne en quatre champs. SetAppearance rend les changements nus : string[].
class SetAppearanceDto {
    [string]$InstanceName
    [string]$Font
    [string]$ColourScheme
    [WslIconDto]$Icon
    [string]$IconImage
}

# Une paire de couleurs de la tuile : son nom d'écran, le haut, le bas, et la
# couleur du texte. GetIconPairs en rend la liste.
class WslIconPairDto {
    [string]$Name
    [string]$Top
    [string]$Bottom
    [string]$TextColor
}

# --- les packs ----------------------------------------------------------------

# Tout ce que la fenêtre des packs montre : ce que l'instance porte, ce
# qu'on peut lui offrir (sa famille, ce qui manque), ce qu'on peut lui
# retirer.
class GetPacksResponseDto {
    [string[]]$Installed = @()
    [WslPackDto[]]$Candidate = @()
    [string[]]$Removable = @()
}

# Un pack par son nom : ses requirements viennent avec lui.
class AddPackDto {
    [string]$InstanceName
    [string]$PackName
}

# Le déroulé : Outcome (installed, already, declined, failed), le code de
# sortie, ce qui est entré, ce qui était déjà là.
class AddPackResponseDto {
    [string]$InstanceName
    [string]$Outcome
    [int]$ExitCode
    [string[]]$Installed = @()
    [string[]]$Skipped = @()
}

class RemovePackDto {
    [string]$InstanceName
    [string]$PackName
}

# Outcome (removed, refused, failed), le code de sortie, et les dépendants
# qui refusent le départ quand il y en a.
class RemovePackResponseDto {
    [string]$InstanceName
    [string]$Outcome
    [int]$ExitCode
    [string[]]$Dependents = @()
}

# Le choix entier rendu par la fenêtre des packs : ce qui entre, ce qui sort,
# par leurs noms.
class ManagePacksDto {
    [string]$InstanceName
    [string[]]$ToAdd = @()
    [string[]]$ToRemove = @()
}

class ManagePacksResponseDto {
    [string]$InstanceName
    [string]$Outcome
    [int]$ExitCode
    [string[]]$Installed = @()
    [string[]]$Removed = @()
    [string[]]$Failed = @()
}

# --- les jeux de couleurs -----------------------------------------------------

# La ligne d'un jeu de couleurs : son nom, le fond, le texte, et les seize
# couleurs qu'un programme peut demander par leur nom (ou leur place dans la
# palette). La console peint ses lignes d'aperçu avec le fond et le texte, la
# fenêtre peint sa grille avec les seize — une seule lecture, deux entrées.
# GetColorSchemes en rend la liste, triée par nom.
class WslColorSchemeDto {
    [string]$Name
    [string]$Background
    [string]$Foreground
    [string]$Black
    [string]$DarkRed
    [string]$DarkGreen
    [string]$DarkYellow
    [string]$DarkBlue
    [string]$DarkMagenta
    [string]$DarkCyan
    [string]$Gray
    [string]$DarkGray
    [string]$Red
    [string]$Green
    [string]$Yellow
    [string]$Blue
    [string]$Magenta
    [string]$Cyan
    [string]$White
}

# --- l'archive ----------------------------------------------------------------

# Permit : le oui de la conversation quand l'instance tourne — l'export
# l'arrête, et l'arrêt lui rend son état ensuite. Le nom de l'archive ne se
# demande pas : XX devient XX_archive, écrasée si elle existe déjà.
class ArchiveDto {
    [string]$InstanceName
    [string]$Format
    [bool]$Permit = $false
}

# Le rapport : le dossier écrit, le tar, le look copié à côté (police,
# couleurs), ce que Docker Desktop savait, et si l'instance a été remise en
# route.
class ArchiveResponseDto {
    [string]$InstanceName
    [string]$ArchiveDir
    [string]$Tar
    [string]$LookFont
    [string]$LookColourScheme
    [string]$Docker
    [bool]$Stopped
}

# ArchiveName : l'archive par son nom suffixé ; InstanceName : la nouvelle
# instance — proposé sans le suffixe, refusé si une instance du même nom
# existe. Docker Desktop : l'instance y entre comme l'archive le dit, sans
# question.
class RestoreDto {
    [string]$ArchiveName
    [string]$InstanceName
}

# SourceName : l'originale ; CopyName : la copie. Duplicate rend le nom de
# l'instance neuve, nu. La place est vérifiée dans la copie même, et refusée
# si elle manque — le pic : deux fois le disque. Docker Desktop : la copie y
# entre comme l'originale, sans question.
class DuplicateDto {
    [string]$SourceName
    [string]$CopyName
}

# Ce que la corbeille rend : l'archive effacée, par son nom.
class DeleteArchiveResponseDto {
    [string]$ArchiveName
}

# Ce que la restauration rend : l'archive d'où elle vient, l'instance rebâtie.
class RestoreResponseDto {
    [string]$ArchiveName
    [string]$InstanceName
}

# Ce que la copie rend : l'originale et la copie.
class DuplicateResponseDto {
    [string]$SourceName
    [string]$CopyName
}

# Ce que l'arrêt et le départ rendent : le nom, porté.
class RestartResponseDto {
    [string]$InstanceName
}

# Ce que le shell rend : l'instance ouverte, et si le profil Terminal l'a
# portée (faux : la console nue, le repli).
class OpenResponseDto {
    [string]$InstanceName
    [bool]$Profile
}

# Ce que la visite du look rend : l'instance revisitée et les changements,
# dans les mots du service.
class SetAppearanceResponseDto {
    [string]$InstanceName
    [string[]]$Changes = @()
}

# Ce que l'ouverture des réglages rend : le chemin du .wslconfig, et s'il est
# né de son gabarit à cette ouverture.
class WslConfigResponseDto {
    [string]$Path
    [bool]$Created
}

# Le tableau de la liste, d'un bloc : les lignes, les dossiers laissés
# derrière, et qui tourne — assemblés par le presenter, qui lit au service.
class ListResponseDto {
    [object[]]$Rows = @()
    [object[]]$Orphans = @()
    [string[]]$Running = @()
}

# The two Docker Desktop gestures: the name and the restart answer in, the
# name and what the restart became out - "restarted", "started", or
# "pending" when it would not; an empty string when it was not asked, and
# the name applies at Docker Desktop's next start.
class RegisterDockerDto {
    [string]$InstanceName
    [bool]$Restart = $true
}

class RegisterDockerResponseDto {
    [string]$InstanceName
    [string]$Restart = ""
}

class UnregisterDockerDto {
    [string]$InstanceName
    [bool]$Restart = $true
}

class UnregisterDockerResponseDto {
    [string]$InstanceName
    [string]$Restart = ""
}

