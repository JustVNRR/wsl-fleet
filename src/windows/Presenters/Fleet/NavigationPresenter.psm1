using module ..\ActionResult.psm1
using module .\BrowsePresenter.psm1
using module .\SettingsPresenter.psm1
using module ..\..\Views\cli\MenuCli.psm1

class NavigationPresenter {

    hidden [object]$Browse
    hidden [object]$Settings
    hidden [ConsoleCli]$Console
    hidden [System.Collections.Generic.List[object]]$Stack

    NavigationPresenter([object]$browse, [object]$settings) {
        $this.Browse = $browse
        $this.Settings = $settings
        $this.Console = [ConsoleCli]::new()
        $this.Stack = [System.Collections.Generic.List[object]]::new()
    }

    [ActionResult] Run([string]$kind, [hashtable]$Presenters) {
        $this.Stack.Clear()
        $this.Stack.Add([pscustomobject]@{ Kind = $kind; Data = $null })
        while ($this.Stack.Count -gt 0) {
            $top = $this.Stack[$this.Stack.Count - 1]
            $this.Console.Clear()
            $result = $this.Step($top, $Presenters)
            if ($null -ne $result) { return $result }
        }
        return [ActionResult]::Ok("Navigate : cancelled")
    }

    hidden [object] Step([object]$top, [hashtable]$Presenters) {
        switch ("$($top.Kind)") {
            "instances" {
                $row = $this.Browse.AskInstances()
                if ($null -eq $row) { return $this.Pop($this.Browse, "Instances") }
                $this.Stack.Add([pscustomobject]@{ Kind = "instance-actions"; Data = $row })
                return $null
            }
            "instance-actions" {
                $action = $this.Browse.AskAction($top.Data)
                if ($null -eq $action) { $this.Stack.RemoveAt($this.Stack.Count - 1); return $null }
                $this.Console.Clear()
                $result = (& $action.Action "$($top.Data.Name)" $Presenters)
                if ("$($result.Status)" -eq "Ok" -and "$($result.Message)" -like "*: cancelled") { return $null }
                return $result
            }
            "archives" {
                $row = $this.Browse.AskArchives()
                if ($null -eq $row) { return $this.Pop($this.Browse, "Archives") }
                $this.Stack.Add([pscustomobject]@{ Kind = "archive-actions"; Data = $row })
                return $null
            }
            "archive-actions" {
                $action = $this.Browse.AskAction($top.Data)
                if ($null -eq $action) { $this.Stack.RemoveAt($this.Stack.Count - 1); return $null }
                $this.Console.Clear()
                $result = (& $action.Action "$($top.Data.Name)" $Presenters)
                if ("$($result.Status)" -eq "Ok" -and "$($result.Message)" -like "*: cancelled") { return $null }
                return $result
            }
            "settings" {
                $item = $this.Settings.AskMenu()
                if ($null -eq $item) { return $this.Pop($this.Settings, "Settings") }
                if ("$($item.Key)" -eq "availables packs") {
                    $this.Stack.Add([pscustomobject]@{ Kind = "packs"; Data = $null })
                    return $null
                }
                $this.Console.Clear()
                $result = (& $item.Action "" $Presenters)
                if ("$($result.Status)" -eq "Ok" -and "$($result.Message)" -like "*: cancelled") { return $null }
                return $result
            }
            "packs" {
                $pack = $this.Settings.AskPack()
                if ($null -eq $pack) { return $this.Pop($this.Settings, "Settings") }
                $this.Stack.Add([pscustomobject]@{ Kind = "pack"; Data = $pack })
                return $null
            }
            "pack" {
                $choice = $this.Settings.AskPackAction($top.Data)
                if ($null -eq $choice) { $this.Stack.RemoveAt($this.Stack.Count - 1); return $null }
                $this.Console.Clear()
                $outcome = $null
                switch ("$($choice.Key)") {
                    "edit" { $outcome = $this.Settings.Edit($top.Data) }
                    "duplicate" { $outcome = $this.Settings.Duplicate($top.Data) }
                    "delete" { $outcome = $this.Settings.Delete($top.Data) }
                }
                if ($null -eq $outcome) { return $null }
                return $outcome
            }
        }
        return $null
    }

    hidden [object] Pop([object]$presenter, [string]$label) {
        $this.Stack.RemoveAt($this.Stack.Count - 1)
        if ($this.Stack.Count -gt 0) { return $null }
        if ("$($presenter.Miss)" -eq "none") { return [ActionResult]::Nok("$label : none") }
        if ("$($presenter.Miss)" -eq "failure") { return [ActionResult]::Nok("$label : $($presenter.Error)") }
        return [ActionResult]::Ok("$label : cancelled")
    }
}
