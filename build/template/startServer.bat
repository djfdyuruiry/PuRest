@ECHO off

IF NOT DEFINED PUREST (
	ECHO "Please define the environment variable 'PUREST' with the install path of PuRest! Quitting..."
	EXIT /B
)

IF DEFINED LUA_PATH SET oldLuaPath=LUA_PATH
IF DEFINED LUA_CPATH SET oldDllPath=LUA_CPATH

set OLDDIR=%CD%
CD /D "%PUREST%"

IF DEFINED PUREST_WEB (
	ECHO "Using PUREST_WEB as html directory for server => '%PUREST_WEB%'"
)
IF NOT DEFINED PUREST_WEB (
	SET PUREST_WEB=%CD%\web
	ECHO "Using web dir in PUREST path as html directory for server => '%CD%\web'"
)

SET LUA_PATH=?;?.lua;.\?.lua;%CD%\?\?.lua;%CD%\?\init.lua;%CD%\?.lua;%CD%\init.lua;%CD%\?\src\?.lua;%CD%\init.lua;%CD%\?\src\?\?.lua;%CD%\?\src\init.lua;%PUREST_WEB%\?\?.lua;%PUREST_WEB%\?\init.lua;%PUREST_WEB%\?.lua;%PUREST_WEB%\init.lua;%PUREST_WEB%\?\src\?.lua;%PUREST_WEB%\init.lua;%PUREST_WEB%\?\src\?\?.lua;%PUREST_WEB%\?\src\init.lua;
SET LUA_CPATH=%CD%\bin\?.dll
SET PUREST_CFG=%CD%\cfg\cfg.lua

cd bin

"lua5.1.exe" -e "require 'PuRest.load'"

CD /D "%OLDDIR%"

IF DEFINED oldLuaPath SET LUA_PATH=oldLuaPath
IF DEFINED oldDllPath SET LUA_CPATH=oldDllPath
