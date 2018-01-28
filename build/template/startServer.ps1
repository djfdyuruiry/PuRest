. "$PSScriptRoot/initEnvironment.ps1"

$ErrorActionPreference = "Continue"

lua -e "require 'PuRest.load'"

# dump logs to console
Get-ChildItem "$PSScriptRoot/web" -Filter "*.log" | ForEach-Object `
{ 
	printWithHeader $_.Name

	Write-Host
	Get-Content $_.FullName
	Write-Host
}

if ([Environment]::UserInteractive)
{
	Read-Host "Press enter to exit..."
}
