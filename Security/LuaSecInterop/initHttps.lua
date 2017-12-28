local ssl = require "ssl"

local AprToLuaSocketWrapper = require "PuRest.Security.LuaSecInterop.AprToLuaSocketWrapper"
local LuaSecToAprSocketWrapper = require "PuRest.Security.LuaSecInterop.LuaSecToAprSocketWrapper"
local ServerConfig = require "PuRest.Config.resolveConfig"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

--- HTTPS params table using the server config.
local HTTPS_PARAMS =
{
    mode = "server",
    protocol = ServerConfig.https.encryption,
    key = ServerConfig.https.key,
    certificate = ServerConfig.https.certificate,
    verify = "none",
    options = {"all"},
    ciphers = "ALL:!ADH:@STRENGTH",
}

if not ServerConfig.https.enableSSL then
    -- If SSL is not enabled explictly turn it off in params options.
    table.insert(HTTPS_PARAMS.options, "no_sslv2")
    table.insert(HTTPS_PARAMS.options, "no_sslv3")
end

--- Establish a HTTPS connection with a client socket using SSL
-- params in current server config. If there was a problem setting
-- up the encrypted socket or preforming the connection handshake, an
-- error is thrown.
--
-- @param aprSocket APR client socket object to be encrypted for HTTPS communication.
-- @return A LuaSecToAprSocketWrapper object which can be used in place of an APR client socket.
--
local function initHttps (aprSocket)
	validateParameters(
		{
			aprSocket = {aprSocket, Types._userdata_}
		}, "initHttps")

	local peerAddress, peerPort = aprSocket:addr_get("remote")
	local luaSecSocket, sslWrapError = ssl.wrap(AprToLuaSocketWrapper(aprSocket), HTTPS_PARAMS)

	if not luaSecSocket or sslWrapError then
		error(string.format("Error wrapping socket for HTTPS encryption: %s", sslWrapError or "unknown error."))
	end

	local status, handshakeError = luaSecSocket:dohandshake()

	if not status or handshakeError then
		error(string.format("Error preforming HTTPS handshake: %s", handshakeError or "unknown error."))
	end

	return LuaSecToAprSocketWrapper(luaSecSocket, aprSocket, peerAddress, peerPort)
end

return initHttps
