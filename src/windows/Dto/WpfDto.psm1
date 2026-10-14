# ==============================================================================
# LES DTO DU WPFSERVICE, TOUS
# ==============================================================================
# Un thème rendu où l'utilisateur pointe : la source entière (le fichier du
# thème, ou le chart pour « Default »), et la cible.
class ExportThemeDto {
    [string]$Source
    [string]$Target
}

# La règle : méthode Xxx → XxxDto en entrée, XxxResponseDto en retour — quand
# il y a quelque chose à porter : sans paramètre, pas de Dto ; sans retour,
# pas de ResponseDto ; un seul champ, pas de classe — le bool ou la chaîne se
# passent nus ; une classe à partir de deux champs. Chaque Dto ne sert qu'à
# sa méthode — un Dto ne porte que des Dto, et chaque nom dit son objet.

# Le look de la fenêtre en clair : sa police, sa taille, son thème de couleurs
# et sa variante. GetTheme le rend ; les Set* le posent pièce par pièce.
class WpfThemeDto {
    [string]$FontFamily
    [int]$FontSize
    [string]$ColorTheme
    [string]$Variant
}
