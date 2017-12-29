if ([String]::IsNullOrEmpty($env:PUREST_WEB))
{
	$env:PUREST_WEB = "$PSScriptRoot/web"
}

if ([String]::IsNullOrEmpty($env:PUREST_CFG))
{
	$env:PUREST_CFG = "$PSScriptRoot/cfg/cfg.lua"
}

Write-Host "Using PUREST_WEB as html directory for server => '$($env:PUREST_WEB)'"

$defaultLuaPath = lua -e "print(package.path)"
$defaultLuaCPath = lua -e "print(package.cpath)"

$luaBasePath = "$PSScriptRoot/lua"
$env:LUA_PATH = "$defaultLuaPath;?;?.lua;./?.lua;$luaBasePath/?/?.lua;$luaBasePath/?/init.lua;$luaBasePath/?.lua;$luaBasePath/init.lua;$luaBasePath/?/src/?.lua;$luaBasePath/init.lua;$luaBasePath/?/src/?/?.lua;$luaBasePath/?/src/init.lua;$($env:PUREST_WEB)/?/?.lua;$($env:PUREST_WEB)/?/init.lua;$($env:PUREST_WEB)/?.lua;$($env:PUREST_WEB)/init.lua;$($env:PUREST_WEB)/?/src/?.lua;$($env:PUREST_WEB)/init.lua;$($env:PUREST_WEB)/?/src/?/?.lua;$($env:PUREST_WEB)/?/src/init.lua"
$env:LUA_CPATH = "$defaultLuaCPath;$PSScriptRoot/bin/?.dll"

Write-Host "Environment variables at server launch:"
Get-ChildItem env:

$ErrorActionPreference = "Continue"

lua -e "require 'PuRest.load'"

Read-Host "Press enter to exit..."
