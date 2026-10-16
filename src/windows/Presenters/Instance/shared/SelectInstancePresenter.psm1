using module ..\..\BasePresenter.psm1

class SelectInstancePresenter : BasePresenter {

    [string]$Miss = ""

    SelectInstancePresenter([string]$viewsRoot, [string]$viewType) : base($viewsRoot, $viewType, "Instance") {
    }

    [string] Pick([string]$target, [object[]]$rows) {
        $this.Miss = ""
        if ($target) { return $target }

        $all = @($rows | Where-Object { -not $_.IsArchive })
        if ($all.Count -eq 0) {
            $this.GetView("SelectInstance").ShowNoInstances()
            $this.Miss = "none"
            return ""
        }

        $picked = $this.GetView("SelectInstance").AskOffered($all)
        if (-not $picked) {
            $this.Miss = "cancelled"
            return ""
        }
        return "$picked"
    }
}
