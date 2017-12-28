@ECHO off
@REM TODO: redo this in powershell

IF DEFINED LUA_PATH SET oldLuaPath=LUA_PATH
IF DEFINED LUA_CPATH SET oldDllPath=LUA_CPATH

set OLDDIR=%CD%
CD /D "%~dp0"

IF NOT DEFINED PUREST_WEB (
	SET PUREST_WEB=%CD%\web
)

ECHO "Using PUREST_WEB as html directory for server => '%PUREST_WEB%'"

SET LUA_PATH=?;?.lua;.\?.lua;%CD%\?\?.lua;%CD%\?\init.lua;%CD%\?.lua;%CD%\init.lua;%CD%\?\src\?.lua;%CD%\init.lua;%CD%\?\src\?\?.lua;%CD%\?\src\init.lua;%PUREST_WEB%\?\?.lua;%PUREST_WEB%\?\init.lua;%PUREST_WEB%\?.lua;%PUREST_WEB%\init.lua;%PUREST_WEB%\?\src\?.lua;%PUREST_WEB%\init.lua;%PUREST_WEB%\?\src\?\?.lua;%PUREST_WEB%\?\src\init.lua;
SET LUA_CPATH=%CD%\bin\?.dll
SET PUREST_CFG=%CD%\cfg\cfg.lua

"lua" -e "require 'PuRest.load'"

CD /D "%OLDDIR%"

IF DEFINED oldLuaPath SET LUA_PATH=oldLuaPath
IF DEFINED oldDllPath SET LUA_CPATH=oldDllPath
