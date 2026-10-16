# Runs a command of the template with the stand-ins (fake-docker\) ahead on
# the PATH - docker, and the curl the registry check's Hub door calls - so
# everything before a deployment can be exercised with no Docker Desktop, no
# network and no instance. The answers come on standard input, the way the
# numbered menus read them when there is no console.
#
# The paths come from this file's own folder: the repository may sit anywhere.
$env:PATH = (Join-Path $PSScriptRoot "fake-docker") + [IO.Path]::PathSeparator + $env:PATH

& (Join-Path $PSScriptRoot "..\..\wsl-fleet.ps1") @args

if ($null -eq $LASTEXITCODE) { exit 0 }
exit $LASTEXITCODE
