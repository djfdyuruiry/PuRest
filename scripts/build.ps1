# build paths
$projectRoot = "$PSScriptRoot/.."
$templateDir = "$projectRoot/build/template"
$luaSrcDir = "$projectRoot/src"

$releaseDir = "$projectRoot/build/release"
$releaseWebDir = "$projectRoot/build/release/web"
$releaseLuaDir = "$projectRoot/build/release/lua"

# drop and create release directory
if (Test-Path $releaseDir)
{
    Remove-Item $releaseDir -Recurse -Force # -Verbose
}

New-Item $releaseDir -ItemType Directory -Force # -Verbose

# copy release template and lua code
Copy-Item "$templateDir/*" $releaseDir -Recurse -Container -Force # -Verbose
Copy-Item "$luaSrcDir/*" $releaseLuaDir -Recurse -Container -Force # -Verbose

# generate luadoc
& "$projectRoot/scripts/generateDocumentation.ps1"

# copy favico
Copy-Item "$projectRoot/resources/favicon.ico" $releaseWebDir -Force # -Verbose

# copy server config
Copy-Item "$luaSrcDir/PuRest/Config/DefaultConfig.lua" "$releaseDir/cfg/cfg.lua" -Force # -Verbose

# clean build placeholders from release
Get-ChildItem -Path $releaseDir -File -Include "build.txt" -Recurse | Remove-Item -Force # -Verbose
