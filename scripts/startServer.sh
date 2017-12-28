#!/bin/sh
# TODO: redo this in powershell

# Uncomment this if you do not have PuRest paths set up.
#./env_script_lua.sh

# Recommended to run the server bootloader with sudo.
# TODO: rework server to run without the need for superuser access
lua -e "require 'PuRest.load'"