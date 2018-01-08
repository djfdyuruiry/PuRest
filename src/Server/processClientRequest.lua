local luaLinq = require "lualinq"
local from = luaLinq.from

local convertClientSocketFileDescriptorToHttpDataPipe = require "PuRest.Util.Networking.convertClientSocketFileDescriptorToHttpDataPipe"
local getMatchingSite = require "PuRest.Server.getMatchingSite"
local getSocketFileDescriptorFromThreadQueue = "PuRest.Server.getSocketFileDescriptorFromThreadQueue"
local HttpDataPipe = require "PuRest.Http.HttpDataPipe"
local log = require "PuRest.Logging.FileLogger"
local LogLevelMap = require "PuRest.Logging.LogLevelMap"
local ServerConfig = require "PuRest.Config.resolveConfig"
local try = require "PuRest.Util.ErrorHandling.try"
local Timer = require "PuRest.Util.Chrono.Timer"
local Types = require "PuRest.Util.ErrorHandling.Types"
local Url = require "PuRest.Http.Url"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

--- Determine socket type passed in and create a
-- HttpDataPipe object wrapper for it and return this.
--
-- @param socket The socket object to inspect.
-- @param threadQueue The server thread queue to request client socket from.
-- @return HttpDataPipe object wrapper for client socket.
--
local function resolveDataPipe(socket, threadQueue)
	if socket then
		if type(socket) == Types._number_ then
			-- Raw socket file descriptor
			return convertClientSocketFileDescriptorToHttpDataPipe(socket)
		elseif type(socket) == Types._table_ then
			-- Existing HttpDataPipe instance
			return socket
		elseif type(socket) == Types._userdata_ then
			-- LuaSocket Socket instance
			return HttpDataPipe({socket = socket})
		end
	elseif threadQueue then
		-- No socket passed in, fetch file descriptor from thread queue
		local socketFileDescriptor = getSocketFileDescriptorFromThreadQueue(threadQueue)
		
		return convertClientSocketFileDescriptorToHttpDataPipe(socketFileDescriptor)
	else
		error("Error resolving data pipe to use for request: a valid network source(Socket File Descriptor/HttpDataPipe/LuaSocket Socket/ThreadQueue) was not passed in.")
	end
end

--- Attempt to process a client request from the current client socket. A thread queue
-- or a Socket/HttpDataPipe should be passed in to provide a network I/O context.
--
-- @param threadQueue OPTIONAL The server thread queue to request client socket from.
-- @param defaultSite Default site which handles requests when unable to serve request or an error occurs.
-- @param socket OPTIONAL Client Socket/HttpDataPipe object.
-- @return A client request pipe and the server state generated by the request ({method,location,protocol,readInRequest...}).
--
local function processClientRequest (threadQueue, defaultSite, socket)
	validateParameters(
		{
			defaultSite = {defaultSite, Types._table_}
		}, "processClientRequest")

	if not threadQueue and not socket then
		error("processClientRequest requires either a threadQueue or a socket")
	end

	local clientDataPipe = resolveDataPipe(socket, threadQueue)
    local readInRequest = false

    local timer

	local httpLocation
    local serverState =
    {
        method = "GET",
        location = "/",
        protocol = "http"
    }

	try(function ()
		log(string.format("Attempting to fetch request from client '%s'.", clientDataPipe.getClientPeerName(true)), LogLevelMap.INFO)
		local method, location, protocol = clientDataPipe.getMethodLocationProtocol()

		if not method or not location or not protocol then
			return
        end

        location = Url.unescape(location)

		readInRequest = true
		log(string.format("Processing server state presented by connection with client '%s'.",
			clientDataPipe.getClientPeerName(true)), LogLevelMap.INFO)

		serverState =
		{
			method = method,
			location = location,
			protocol = protocol
        }

		--- Attempt to load site from available sites.
        timer = Timer()

        local site = getMatchingSite(location, protocol)
        httpLocation = string.format("%s://%s%s", protocol:match("(.+)[/]"), "*", location)

        log(string.format("Getting site took %s ms.", timer.endTimeNow()), LogLevelMap.DEBUG)

		if site then
			log(string.format("Site found for request location '%s': %s", site.urlNamespace, httpLocation),
			LogLevelMap.INFO)

			serverState.location = httpLocation

			site.processServerState(clientDataPipe, serverState)
		else
			log(string.format("No site was found for request location '%s'.", httpLocation or ""), LogLevelMap.WARN)
			log(string.format("Handling request location '%s' using default site for HTML directory '%s' root",
				httpLocation or "?",
				ServerConfig.htmlDirectory), LogLevelMap.INFO)

			defaultSite.processServerState(clientDataPipe, serverState)
		end
	end)
	.catch(function (ex)
		if tostring(ex):match("Socket Error:") then
			-- Socket error means this thread can no longer do any useful work.
			log(string.format("Error reading data from the socket for client '%s' - %s", clientDataPipe.getClientPeerName(true), ex), LogLevelMap.ERROR)

			readInRequest = false
			return
		end

		serverState.siteError = ex
		log(string.format("An error occurred when looking for a site that matches request location '%s': %s",
			httpLocation or "?",
			(ex or "Unknown Error")), LogLevelMap.ERROR)
		log(string.format("Handling request location '%s' using default site for HTML directory '%s' root",
			httpLocation or "?",
			ServerConfig.htmlDirectory), LogLevelMap.INFO)

		defaultSite.processServerState(clientDataPipe, serverState)
	end)

	serverState.readInRequest = readInRequest

	return clientDataPipe, serverState
end

return processClientRequest
