# ==============================================================================
# LES DTO DU PACKCATALOGSERVICE, TOUS
# ==============================================================================
# La règle : méthode Xxx → XxxDto en entrée, XxxResponseDto en retour — quand
# il y a quelque chose à porter : sans paramètre, pas de Dto ; sans retour,
# pas de ResponseDto ; un seul champ, pas de classe — le bool ou la chaîne se
# passent nus ; une classe à partir de deux champs. Chaque Dto ne sert qu'à
# sa méthode — un Dto ne porte que des Dto, et chaque nom dit son objet.

# La ligne du pack : ce que les fenêtres montrent — son nom, sa description.
# GetAllPacks en rend la liste, GetPack en rend une.
class WslPackDto {
    [string]$Name
    [string]$Description
    # La famille — la liste du catalogue (Réglages) la montre.
    [string]$Family
}

# SourceName : le pack copié ; NewName : le neuf ; la description réécrite
# dans la copie. CreatePack rend le nom du pack créé, nu.
class CreatePackDto {
    [string]$SourceName
    [string]$NewName
    [string]$Description
}

# PackName : le pack dont la ligne change ; Description : la nouvelle.
class SetPackDescriptionDto {
    [string]$PackName
    [string]$Description
}
