#!/bin/bash

# TODO: manage dependencies via lua rockspec instead of script

function assertLuaDependencyInstalled {
  if [[ $(luarocks list) != *$1* ]]; then
      echo "Error: lua dependecy $1 did not successfully install, see luarocks output above" >&2
      exit 1
  fi
}

function assertCommandAvailable {
    if ! [ -x "$(command -v $1)" ]; then
      echo "Error: $1 is not installed, please install this to get lua dependencies" >&2
      echo "  see $2" >&2
      exit 1
    fi

    echo "Found command $1 at path $(command -v $1)"
}

assertCommandAvailable lua http://www.lua.org/download.html
assertCommandAvailable luarocks https://github.com/luarocks/luarocks/wiki/Download

# TODO: create luarock to install json.lua from http://regex.info/code/JSON.lua OR https://github.com/rxi/json.lua
# TODO: fix non-lua dependencies for lua-apr, luasec and alien
luaDependencies=( lua-apr luasec lrexlib-pcre lualogging lzlib lualinq xml alien )

for luaDependency in "${luaDependencies[@]}"
do
  echo "Installing lua dependency ${luaDependency}..."

	luarocks install ${luaDependency}
  assertLuaDependencyInstalled ${luaDependency}

  echo "Installed lua dependency ${luaDependency}"
done
