# ==============================================================================
# LE RÉSULTAT D'UN GESTE
# ==============================================================================
# Ce que chaque méthode d'un contrôleur rend : le statut, et une phrase —
# « Build 'wagon' : ok », « Build 'wagon' : la phrase du refus », « Open :
# cancelled » quand l'utilisateur a abandonné (rien n'a échoué). L'entrée du
# cli en tire son code de sortie, la fenêtre sa ligne de trail ; le journal
# viendra s'y brancher. Près des presenters : c'est la forme de leur porte,
# pas une forme de service.

enum ActionResultStatus {
    Ok
    Nok
}

class ActionResult {
    [ActionResultStatus]$Status
    [string]$Message

    ActionResult([ActionResultStatus]$status, [string]$message) {
        $this.Status = $status
        $this.Message = $message
    }

    # Les deux naissances usuelles — le message seul les distingue.
    static [ActionResult] Ok([string]$message) {
        return [ActionResult]::new([ActionResultStatus]::Ok, $message)
    }

    static [ActionResult] Nok([string]$message) {
        return [ActionResult]::new([ActionResultStatus]::Nok, $message)
    }
}
