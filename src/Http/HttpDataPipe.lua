local functionProxy = require "PuRest.Util.ParameterPassing.functionProxy"
local methodProxy = require "PuRest.Util.ParameterPassing.methodProxy"
local ServerConfig = require "PuRest.Config.resolveConfig"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

local luaSocket = require "socket-lanes"
local dns = luaSocket.dns

local CONSTRUCTOR_PARAM_ERR = "HttpDataPipe: You must pass a table containing either {host=..,port=..} if you want " ..
	"a server data pipe or {socket=..} when building a client HTTP channel."

--- Abstract interface for server components to use to digest a HTTP data stream
-- from a network socket. Server config is applied to socket config and server
-- sockets are bound in the constructor.
--
-- @param params A table containing either {host=..,port=..}
--							 if you want a server data pipe or {socket=..}
--							 when building a client HTTP channel.
--
local function HttpDataPipe (params)
	validateParameters(
		{
			params = {params, Types._table_}
		},
		"HttpDataPipe")

	-- Proxy class instance.
	local dataPipe
	-- Full implementation class instance.
	local socket
	local baseSocketIsLuaSecWrapper = false

    --- Check if the base socket is a LuaSec socket wrapper.
    -- (Use with client sockets only.)
    --
    -- @return Is the base socket a LuaSec socket wrapper.
    --
	local function isBaseSocketLuaSocketWrapper ()
		return baseSocketIsLuaSecWrapper
	end

	--- Read in a line from the data pipe and pattern match inital HTTP request line.
	--
	-- @return Captures for method, location and protocol.
    --
	local function getMethodLocationProtocol ()
		local request = dataPipe.readLine() or ""
		return request:match('^(%w+)%s+(%S+)%s+(%S+)')
	end

	--- Get all headers from the start of a HTTP request stream.
    --
	-- @return HTTP header dictionary.
	--
    local function getHeaders ()
		local headers = {}
		local line = dataPipe.readLine()

		while line do
			line = line:gsub("\r", "") or line
			local name, value = line:match '^(%S+):%s+(.-)$'

			-- An empty line separates request headers and the body.
			if not name then
				break
			end

			headers[name] = value or ""
			line = dataPipe.readLine()
		end

		return headers
    end

    --- Determine if socket is client or server and bind to the
    -- specified host an port, after type checking, for server ports.
    -- Server connection backlog config value is applied here, for server ports,
    -- as well as recieve buffer size (server) and send buffer size (client).
    --
    -- An abstraction is then built and returned, below are the available methods:
    --
    -- [In brackets is the socket type needed to make method available.]
    --
    --  waitForClient (Server)                -> Wait for a client to connect and return client socket.
    --
    --  isBaseSocketLuaSocketWrapper (Server) -> Is the base socket an instance of LuaSocketWrapper?
    --
    --  getClientPeerName (Client)            -> Get the network peer name and socket, pass in true to get both values
    --                                           together in one string delimited by a ':'.
    --
    --  getMethodLocationProtocol (Client)    -> See HttpDataPipe getMethodLocationProtocol method above.
    --
    --  getHeaders (Client)                   -> See HttpDataPipe getHeaders method above.
    --
    --  read (Client)                         -> Read data from socket. (format specifier can be passed in)
    --
    --  readLine (Client)                     -> Read a line of text from the socket.
    --
    --  readChars (Client)                    -> Read a number of characters from the socket,
    --                                           only parameter is number of chars.
    --
    --  write (Client)                        -> Write data to the socket.
    --
    --  socket (Server, Client)               -> Get the socket inside the HttpDataPipe.
    --
    --  getHostName (Server, Client)          -> Get the hostname for the socket.
    --
    --  terminate (Server, Client)            -> Close the socket.
    --
	local function construct ()
		-- Validate params table keys.
		if params.host and params.port then
			validateParameters(
				{
					params_host = {params.host, Types._string_},
					params_port = {params.port, Types._number_}
				},
				"HttpDataPipe.construct")
		elseif params.socket then
			validateParameters(
				{
					params_socket = {params.socket, Types._userdata_}
				},
				"HttpDataPipe.construct")
		else
			error(CONSTRUCTOR_PARAM_ERR)
		end

		-- TODO: investigate issues with timeouts...
		--local conTimeout = ServerConfig.connectionTimeOutInMs > 0 and ServerConfig.connectionTimeOutInMs * 1000 or 10000

		if params.host and params.port then
			local _, bindErr

			socket = luaSocket.tcp()
			_, bindErr = socket:bind(params.host, params.port)

            if not socket or bindErr then
                error(string.format("Unable to bind server socket to %s:%d: %s.", params.host, params.port,
                    (bindErr or "unknown error")))
			end
			
			local conBacklog = ServerConfig.connectionBacklog > 0 and ServerConfig.connectionBacklog or "max"
			
			local listenErr
			_, listenErr = socket:listen(conBacklog)

            if listenErr then
                error(string.format("Unable to listen on server socket to %s:%d: %s.", params.host, params.port,
                    (listenErr or "unknown error")))
			end
			
			if ServerConfig.socketReceiveBufferSize > 0 then
				socket:setoption("rcvbuf", ServerConfig.socketReceiveBufferSize)
			end

			dataPipe =
			{
				waitForClient = function ()
					return socket:acceptfd()
				end,
				isBaseSocketLuaSocketWrapper = isBaseSocketLuaSocketWrapper
			}
		else
			socket = params.socket

			if ServerConfig.socketSendBufferSize > 0 then
				socket:setoption("sndbuf", ServerConfig.socketSendBufferSize)
			end

			dataPipe =
			{
				getClientPeerName = function (format)
				    local host, port = socket:getpeername()				
					if format then
                        return tostring(host) .. ":" .. tostring(port) 
                    else
                        return tostring(host), tostring(port)
                    end
				end,
				getMethodLocationProtocol = getMethodLocationProtocol,
				getHeaders = getHeaders,
				read = methodProxy(socket, "receive"),
				readLine = function ()
					local response, err = socket:receive("*l")

					if err then
						error(string.format("Socket Error: '%s'", tostring(err)))
					end

					return response
				end,
				readChars = methodProxy(socket, "receive"),
				write = methodProxy(socket, "send"),
				isBaseSocketLuaSocketWrapper = isBaseSocketLuaSocketWrapper
			}
		end

		dataPipe.socket = socket
		dataPipe.getHostName = functionProxy(dns.gethostname)
		dataPipe.terminate = methodProxy(socket, "close")

		--socket:timeout_set(conTimeout)

	--[[
		Ignore if this set option fails as this requires admin/sudo access

		SO_DEBUG
			Enable socket debugging. Allowed only for processes with the
			CAP_NET_ADMIN capability or an effective user ID of 0.

		see: http://man7.org/linux/man-pages/man7/socket.7.html
	]]
		pcall(function()
			 socket:setoption('debug', true)
		end)

		return dataPipe
	end

	return construct()
end

return HttpDataPipe
