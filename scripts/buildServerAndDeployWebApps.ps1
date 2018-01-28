$projectRoot = "$PSScriptRoot/.."
$releaseWebDir = "$projectRoot/build/release/web"
$webAppsPath = "$projectRoot/../PuRest-web-apps"

& "$PSScriptRoot/build.ps1"

# copy in web apps repo if present
if (Test-Path $webAppsPath)
{
    Copy-Item "$webAppsPath/*" $releaseWebDir -Recurse -Container -Force -Verbose -Exclude ".*"
}
