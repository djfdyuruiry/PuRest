# build paths
$projectRoot = "$PSScriptRoot/.."
$templateDir = "$projectRoot/build/template"
$luaSrcDir = "$projectRoot/src"
$luaTestDir = "$projectRoot/test/unit"
$luaLibDir = "$projectRoot/lib/lua"

$releaseDir = "$projectRoot/build/release"
$releaseWebDir = "$projectRoot/build/release/web"
$releaseLuaDir = "$projectRoot/build/release/lua"

# drop and create release directory
if (Test-Path $releaseDir)
{
    Remove-Item $releaseDir -Recurse -Force -Verbose
}

New-Item $releaseDir -ItemType Directory -Force -Verbose

# copy release template and lua code
Copy-Item "$templateDir/*" $releaseDir -Recurse -Container -Force -Verbose
Copy-Item "$luaSrcDir/*" "$releaseLuaDir/PuRest" -Recurse -Container -Force -Verbose
Copy-Item "$luaTestDir/*" "$releaseDir/test" -Recurse -Container -Force -Verbose

# generate luadoc
& "$projectRoot/scripts/generateDocumentation.ps1"

# copy lua libs
Copy-Item "$luaLibDir/*" $releaseLuaDir -Recurse -Container -Force -Verbose

# copy favico
Copy-Item "$projectRoot/resources/favicon.ico" $releaseWebDir -Force -Verbose

# copy server config
Copy-Item "$luaSrcDir/Config/DefaultConfig.lua" "$releaseDir/cfg/cfg.lua" -Force -Verbose

# clean build placeholders from release
Get-ChildItem -Path $releaseDir -File -Include "build.txt" -Recurse | Remove-Item -Force -Verbose