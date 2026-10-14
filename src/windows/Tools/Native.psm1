# ==============================================================================
# LES LANCEMENTS — LE SOCLE DES DÉPÔTS NATIFS
# ==============================================================================
# Les outils de lancement que les dépôts natifs — wsl.exe, docker.exe —
# partagent. Le motif, mesuré : sous EAP=Stop un programme qui parle sur
# stderr lève avant que son code ne se lise, et un code que personne ne lit
# est un échec qui ressemble à une réussite. Ici le programme s'appelle par
# son nom et ses arguments, jamais par un bloc : un bloc écrit dans une
# méthode de classe lit ses locales par un chemin qui n'est pas celui de
# l'appelant.
#
# L'ancien trio se réduit à deux : Invoke-External disait « lance, jette si
# non-zéro » sans la garde EAP — la même intention, en moins sûr.

# Lance, laisse la sortie couler — le pourquoi d'un échec reste à l'écran —
# lit le code, et jette si non-zéro.
function Invoke-NativeCommand {
    param(
        [string]$Program,
        [string[]]$Arguments = @(),
        [string]$Message = "'$Program' failed."
    )

    $previousEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $Program @Arguments
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousEAP
    }
    if ($exitCode -ne 0) {
        throw "$Message (Exit code: $exitCode)"
    }
}

# Le même appel quand l'échec EST la réponse — une question posée à docker,
# où « non » doit revenir en $false et pas en exception.
function Test-NativeCommand {
    param(
        [string]$Program,
        [string[]]$Arguments = @()
    )

    $previousEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $null = & $Program @Arguments *> $null
        return ($LASTEXITCODE -eq 0)
    } finally {
        $ErrorActionPreference = $previousEAP
    }
}
