local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

--- Wrapper that takes a LuaSec socket object and makes
-- it compatible with an APR socket object, in terms
-- of methods and return values. Assumes the LuaSec socket
-- was created by wrapping an APR socket and encrypting it
-- using LuaSec. Calls to addr_get return cached values and
-- opt_set will not error but is not implemented as of rev.203.
--
-- @param socket LuaSec object to wrap.
-- @param aprSocket Original APR socket used to create LuaSec socket.
-- @param peerAddress The peer address of the APR socket.
-- @param peerPort The peer port of the APR socket.
--
local function LuaSecToAprSocketWrapper (socket, aprSocket, peerAddress, peerPort)
	validateParameters(
		{
			socket = { socket, Types._userdata_ },
			aprSocket = { socket, Types._userdata_ },
            peerAddress = { peerAddress, Types._string_ },
            peerPort = { peerPort, Types._number_ }
		},
		"LuaSecToAprSocketWrapper")

	local luaSecSocket = socket
	local baseAprSocket = aprSocket

	local function getBaseAprSocket ()
		return baseAprSocket
	end

	local function getLuaSecSocket ()
		return luaSecSocket
	end

	return setmetatable(
		{
			__IS_LUASEC_SOCKET_WRAPPER__ = true,
			getLuaSecSocket = getLuaSecSocket,
			getBaseAprSocket = getBaseAprSocket
		},
		{
			__index = function (_, key)
				if key == "fd_get" then
					return function (_, ...)
						return luaSecSocket["getfd"](luaSecSocket, ...)
					end
				end

				if key == "fd_set" then
					return function (_, ...)
						return luaSecSocket["setfd"](luaSecSocket, ...)
					end
				end

				if key == "read" then
					return function (_, ...)
						return luaSecSocket["receive"](luaSecSocket, ...)
					end
				end

				if key == "write" then
					return function (_, ...)
						return luaSecSocket["send"](luaSecSocket, ...)
					end
				end

				-- Base socket calls (cached).
				if key == "addr_get" then
					return function ()
						return peerAddress, peerPort
					end
				end

				if key == "opt_set" then
					return function ()
                        -- TODO: Implement
					end
				end

                -- Preform lookup on LuaSec socket.
				return function (_, ...)
					return luaSecSocket[key](luaSecSocket, ...)
				end
			end
		})
end

return LuaSecToAprSocketWrapper
