local apr = require "apr"

--- Wrapper that takes a APR socket object and makes
-- it compatible with a LuaSocket socket object, in terms
-- of methods and return values. If not socket is passed a
-- new APR socket is created for you inside the wrapper.
--
-- @param socket optional An existing APR socket to use.
--
local function AprToLuaSocketWrapper (socket)
	-- TODO: replace with luasocket
	local socket = socket or apr.socket_create();

	local function getAprSocket ()
		return socket
	end

	return setmetatable(
		{
			__IS_APR_SOCKET_WRAPPER__ = true,
			getAprSocket = getAprSocket
		},
		{
			__index = function (_, key)
				if key == "getfd" then
					return function (_, ...)
						return socket["fd_get"](socket, ...)
					end
				end

				if key == "setfd" then
					return function (_, ...)
						return socket["fd_set"](socket, ...)
					end
				end

				if key == "receive" then
					return function (_, ...)
						return socket["read"](socket, ...)
					end
				end

				if key == "send" then
					return function (_, ...)
						return socket["write"](socket, ...)
					end
				end

                -- Preform lookup on APR socket.
				return function (_, ...)
					return socket[key](socket, ...)
				end
			end
		})
end

return AprToLuaSocketWrapper
