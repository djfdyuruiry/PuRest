$location = Get-Location

Set-Location $PSScriptRoot
gradle
Set-Location $location

& "$PSScriptRoot/build/release/startServer.ps1"
