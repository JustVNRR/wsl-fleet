# Reads every .ps1, .psm1 and .psd1 in the checkout with the parser PowerShell
# itself uses before it runs a file - a parse error left here surfaces the day
# a command runs.
#
# The classes name other files' types through `using module`, which the parser
# settles as it reads the file: every file is read as it is, one by one.
#
# The window's files name the WPF types, and the parser settles those against
# what is loaded: the three assemblies below are loaded first, the ones the
# entry loads before it imports a view. Where they cannot be loaded - a host
# that is not Windows - the types settle nowhere and the errors naming
# System.Windows are left out, with a word saying so: the place that parses
# the views for real is the machine that runs them.
#
# Usage:  pwsh -NoProfile -File tests\tree\parse-check.ps1

$bad = 0
$Root = (Get-Item (Join-Path $PSScriptRoot "..\..")).FullName

$WpfLoaded = $true
foreach ($assembly in "PresentationFramework", "PresentationCore", "WindowsBase", "System.Windows.Forms") {
    try { Add-Type -AssemblyName $assembly -ErrorAction Stop } catch { $WpfLoaded = $false }
}
if (-not $WpfLoaded) {
    Write-Host "note: WPF is not on this host - the System.Windows types cannot settle, those errors are left out."
}

$files = @(Get-ChildItem $Root -Recurse -Include *.ps1, *.psm1, *.psd1 -File |
    Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' })
foreach ($f in $files) {
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$errors)
    foreach ($e in @($errors)) {
        if (-not $WpfLoaded -and "$($e.Message)" -match 'Unable to find type \[(System\.Windows|Windows\.)') { continue }
        Write-Host "::error file=$($f.FullName)::$($e.Message) (line $($e.Extent.StartLineNumber))"
        $bad = 1
    }
}
Write-Host "$($files.Count) file(s) read, $bad failure(s)."
exit $bad
