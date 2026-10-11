@echo off
rem Stand-in for curl.exe, for the Docker Hub door of Test-RegistryImage: the
rem HEAD that door sends is answered here, with no network. The scenes know
rem one reference - alpine:latest, which Hub keeps as library/alpine, tag
rem latest - and know it the way Hub does; anything else answers 404, the way
rem Hub answers a name it does not carry.
set "URL="
for %%A in (%*) do (
    echo %%A| findstr /I "hub.docker.com/v2/repositories" >nul && set "URL=%%A"
)
echo %URL%| findstr /I "library/alpine/tags/latest" >nul && echo 200 || echo 404
exit /b 0
