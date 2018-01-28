. "$PSScriptRoot/initEnvironment.ps1"

printWithHeader "Running PuRest Tests..."

busted "$PSScriptRoot/lua/PuRest/Tests"
