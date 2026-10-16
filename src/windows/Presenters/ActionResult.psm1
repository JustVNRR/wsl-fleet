
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

    static [ActionResult] Ok([string]$message) {
        return [ActionResult]::new([ActionResultStatus]::Ok, $message)
    }

    static [ActionResult] Nok([string]$message) {
        return [ActionResult]::new([ActionResultStatus]::Nok, $message)
    }
}
