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

# Une destination de flotte, AVANT que rien ne bouge : un chemin absolu (son
# disque — pas un « effef » relatif qui se résout contre le dossier courant de
# qui le lit), un disque qui répond, et pas d'« archives » déjà dedans. Rend
# "" quand tout va, sinon la raison : le service jette la raison, les
# formulaires la montrent. Vécu : un « effef » relatif avait tout archivé,
# tout désenregistré et tout déplacé avant que le moindre contrôle ne parle.
function Test-FleetTarget {
    param([string]$Target)
    if (-not $Target) { return "no destination was given." }
    $root = [System.IO.Path]::GetPathRoot($Target)
    # « D: » — deux caractères, un deux-points — vise le dossier courant DU
    # disque : relatif déguisé, refusé comme « effef ».
    if (-not $root -or -not [System.IO.Path]::IsPathRooted($Target) -or ($root.Length -eq 2 -and $root[1] -eq ':')) {
        return "'$Target' is not an absolute folder - give a full path, like 'D:\WSL'."
    }
    if (-not (Test-Path -LiteralPath $root)) {
        return "the drive '$($root.TrimEnd('\'))' does not answer."
    }
    $archives = Join-Path $Target "archives"
    if (Test-Path -LiteralPath $archives) {
        return "'$archives' already exists - move it away first."
    }
    return ""
}
