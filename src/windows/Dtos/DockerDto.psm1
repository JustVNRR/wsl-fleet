# ==============================================================================
# LES DTO DU MONDE DOCKER, TOUS
# ==============================================================================
# La règle : méthode Xxx → XxxDto en entrée, XxxResponseDto en retour — quand
# il y a quelque chose à porter : sans paramètre, pas de Dto ; sans retour,
# pas de ResponseDto ; un seul champ, pas de classe — le bool ou la chaîne se
# passent nus ; une classe à partir de deux champs. Chaque Dto ne sert qu'à
# sa méthode — un Dto ne porte que des Dto, et chaque nom dit son objet.

# La ligne du magasin d'images : le nom de l'image gardée, tel que l'écran
# l'affiche (la date du tar entre parenthèses), et son tar. GetAllSavedImages
# en rend la liste.
class WslDockerImageDto {
    [string]$Name
    [string]$Path
    # Téléversée — la corbeille ne touche qu'à celles-là.
    [bool]$Uploaded
}

# La réponse de la porte : le oui, et le pourquoi quand c'est non — la phrase
# de la porte est l'indice que le console montre en redemandant la référence.
class IsRegistryImageValidResponseDto {
    [bool]$Valid
    [string]$Why
}
