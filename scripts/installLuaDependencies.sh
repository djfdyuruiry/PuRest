#!/bin/bash

# TODO: manage dependencies via lua rockspec instead of script

function assertLuaDependencyInstalled {
  if [[ $(luarocks list) != *$1* ]]; then
      echo "Error: lua dependecy $1 did not successfully install, see luarocks output above" >&2
      exit 1
  fi
}

function installLuaDependencyIfMissing {
  if [[ $(luarocks list) != *$1* ]]; then
    echo "Installing lua dependency $1..."

    luarocks install ${luaDependency}
    assertLuaDependencyInstalled $1

    echo "Installed lua dependency $1"
  else
    echo "Lua dependency $1 is already installed"
  fi
}

function installOpensslIfMissing_MacOsx {
  if [[ $(brew list) != *openssl* ]]; then
    brew install openssl

    # workaround for osx openssl header and lib locations (conform to expected linux paths)
    ln -s /usr/local/opt/openssl/include/openssl /usr/local/include

    for i in /usr/local/opt/openssl/lib/lib*; do 
      ln -vs $i /usr/local/lib; 
    done
  else
    echo "Openssl is already installed"
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

function main {
  assertCommandAvailable lua http://www.lua.org/download.html
  assertCommandAvailable luarocks https://github.com/luarocks/luarocks/wiki/Download

  if [[ "$OSTYPE" == "darwin"* ]]; then
    installOpensslIfMissing_MacOsx
  else
    if ! [ -d "/usr/local/include/openssl" ]; then
      echo "Error: looks like openssl is not installed, this is required for the luasec library" >&2
      echo "  install openssl using your system package manager and try again" >&2
      exit 1
    fi
  fi

  # TODO: create luarock to install json.lua from http://regex.info/code/JSON.lua OR https://github.com/rxi/json.lua
  luaDependencies=( luasocket lanes lua_signal luafilesystem md5 date lzlib lrexlib-pcre lualogging lualinq xml luasec )

  # TODO: ensure alien rock installed if running on windows

  for luaDependency in "${luaDependencies[@]}"; do
    installLuaDependencyIfMissing ${luaDependency}
  done
}

main
