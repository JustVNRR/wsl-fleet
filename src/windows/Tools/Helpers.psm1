
function Format-Size {
    param([double]$Bytes)
    if ($Bytes -ge 1GB) { return ("{0:N1} GB" -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ("{0:N0} MB" -f ($Bytes / 1MB)) }
    return ("{0:N0} KB" -f ($Bytes / 1KB))
}

function Test-ProcessArguments {
    param([object[]]$Values)

    foreach ($Value in $Values) {
        if ("$Value" -match '"' -or "$Value".EndsWith('\')) { return $false }
    }
    return $true
}

function Test-FleetTarget {
    param([string]$Target)
    if (-not $Target) { return "no destination was given." }
    $root = [System.IO.Path]::GetPathRoot($Target)
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
