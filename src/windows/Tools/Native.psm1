
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
