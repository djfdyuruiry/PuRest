#!/bin/bash

# TODO: manage dependencies via lua rockspec instead of script

function assertCommandAvailable {
    if ! [ -x "$(command -v $1)" ]; then
      echo "Error: $1 is not installed, please install this to get lua dependencies" >&2
      echo "  see $2" >&2
      exit 1
    fi
}

assertCommandAvailable lua http://www.lua.org/download.html
assertCommandAvailable luarocks https://github.com/luarocks/luarocks/wiki/Download

# TODO: create luarock to install json.lua from http://regex.info/code/JSON.lua OR https://github.com/rxi/json.lua
luaDependencies=( lua-apr luasec lrexlib-pcre lualogging lzlib lualinq xml alien )

for luaDependency in "${luaDependencies[@]}"
do
	luarocks install ${luaDependency}
done
