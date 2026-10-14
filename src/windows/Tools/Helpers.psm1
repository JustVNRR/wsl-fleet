# ==============================================================================
# LES AIDES PURES
# ==============================================================================
# Les aides qui ne portent aucun objet et ne touchent à rien : elles calculent.
# (L'ancien Tools.psm1 du Modèle — le dossier leur donne leur maison.)

# Des octets en une ligne lisible — sous le gigaoctet, le mégaoctet entier :
# un dixième de mégaoctet est du bruit.
function Format-Size {
    param([double]$Bytes)
    if ($Bytes -ge 1GB) { return ("{0:N1} GB" -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ("{0:N0} MB" -f ($Bytes / 1MB)) }
    return ("{0:N0} KB" -f ($Bytes / 1KB))
}

# Ces valeurs peuvent-elles traverser une ligne de commande assemblée à la
# main ? Une valeur qui porte un guillemet double ou qui finit par un
# antislash casse la ligne — le lanceur refuse au site d'appel, avant.
function Test-ProcessArguments {
    param([object[]]$Values)

    foreach ($Value in $Values) {
        if ("$Value" -match '"' -or "$Value".EndsWith('\')) { return $false }
    }
    return $true
}
