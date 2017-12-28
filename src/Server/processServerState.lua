--- Process the current server state as represented by the given HttpDataPipe.
-- The client socket is obtained by either popping from a thread queue or by
-- directly passing the socket object.
--
-- @param threadId Id of the thread that function is running on.
-- @param threadQueue optional Thread queue that has one client socket pushed onto it.
-- @param sessionThreadQueue Thread queue to use to get session data.
-- @param socket optional Client socket to use when processing request.
-- @param useHttps Use HTTPS when communicating with clients.
--
local function processServerState (threadId, threadQueue, sessionThreadQueue, socket, useHttps)
	local Types = require "PuRest.Util.ErrorHandling.Types"
	local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

	-- Validate function parameters.
	validateParameters(
		{
			threadId = {threadId, Types._number_},
			sessionThreadQueue = {sessionThreadQueue, Types._userdata_},
			useHttps = {useHttps, Types._boolean_}
		}, "processServerState")

	if threadQueue then
		validateParameters(
			{
				threadQueue = {threadQueue, Types._userdata_}
			}, "processServerState")
	elseif socket then
		validateParameters(
			{
				socket = {socket, Types._userdata_}
			}, "processServerState")
	else
		error("processServerState requires a value for either the threadQueue or socket parameter.")
	end

	local apr = require "apr"

	-- Set global thread id.
	local CurrentThreadId = require "PuRest.Util.Threading.CurrentThreadId"
	CurrentThreadId.setCurrentThreadId(threadId)

	-- Get global server config.
	local ServerConfig = require "PuRest.Config.resolveConfig"

	local HttpDataPipe = require "PuRest.Http.HttpDataPipe"
	local log = require "PuRest.Logging.FileLogger"
	local LogLevelMap = require "PuRest.Logging.LogLevelMap"
	local processClientRequest = require "PuRest.Server.processClientRequest"
	local Semaphore = require "PuRest.Util.Threading.Semaphore"
	local SessionData = require "PuRest.State.SessionData"
	local Site = require "PuRest.Server.Site"
	local Timer = require "PuRest.Util.Time.Timer"
    local try = require "PuRest.Util.ErrorHandling.try"

	local clientDataPipe

	local status, err = pcall(function ()
		local keepConnectionAlive = false
		local defaultSite = Site("http", "/", nil, ServerConfig.htmlDirectory, true)
		local timeout = os.time() + ServerConfig.httpKeepAliveTimeOutInSecs

		SessionData.setThreadQueue(sessionThreadQueue)

		-- Init HTTPS security if required.
		if useHttps then
			log("Server client sockets required by configuration to use HTTPS encryption.")			
			log("Attempting to encrypt socket for HTTPS communication.")
			   
            try(function() 
			    local initHttps = require "PuRest.Security.LuaSecInterop.initHttps"
                local httpsSocket = initHttps(socket or threadQueue:pop())
                
			    log("Successfully encrypted client socket for use as HTTPS data pipe.")
			    
                clientDataPipe = HttpDataPipe({socket = httpsSocket})
			end)
			.catch(function(ex)
                error(string.format("Error encrypting client socket for HTTPS communication: %s", ex))
            end)             
		end

		-- Main HTTP request loop, repeats when HTTP/1.1 Keep-Alive is requested by client.
		repeat
			local timer = Timer()
			local socketToUse = clientDataPipe and clientDataPipe or socket
			local status, errOrClientDataPipe, serverState  = pcall(processClientRequest, threadQueue, defaultSite, socketToUse, singleThread)

			if not status then
				-- Shutdown request loop if server side error occurred during request handling.
				local err = errOrClientDataPipe

				log(string.format("Error processing/reading client request: %s", err), LogLevelMap.ERROR)
				keepConnectionAlive = false
			else
				-- Log successful request handling and check if socket connection should be kept alive.
				clientDataPipe = errOrClientDataPipe
				keepConnectionAlive = serverState.keepConnectionAlive

				if keepConnectionAlive and serverState.readInRequest then
					-- Extend keep alive timeout at client's request.
					timeout = timeout + ServerConfig.httpKeepAliveTimeOutInSecs
					log(string.format("Read data from client '%s', keeping connection alive and extending request timeout to epoch %d.",
						clientDataPipe.getClientPeerName(true), timeout), LogLevelMap.INFO)
				elseif serverState.readInRequest then
					log(string.format("Read request from client '%s'.",
						clientDataPipe.getClientPeerName(true)), LogLevelMap.INFO)
				end

				if serverState.readInRequest then
					log(string.format("Client request took %s ms.", timer.endTimeNow()), LogLevelMap.DEBUG)
					log("==== CLIENT REQUEST COMPLETE ====", LogLevelMap.DEBUG)
				end
			end

			if keepConnectionAlive then
				-- Prevent high CPU usage when waiting for another request.

				-- TODO: replace with luasocket
				apr.sleep(0.01)
			end
		until not keepConnectionAlive or os.time() >= timeout

		if keepConnectionAlive and os.time() >= timeout then
			-- Detect and report HTTP keep-alive timeout.
			log(string.format("Timeout while waiting for more requests from client '%s'.",
				clientDataPipe.getClientPeerName(true)), LogLevelMap.INFO)
		end

		if clientDataPipe then
			log(string.format("Closing socket connection with client '%s'.",
				clientDataPipe.getClientPeerName(true)), LogLevelMap.INFO)
			clientDataPipe.terminate()
		end
	end)

	if not status then
		-- Detect any errors that occurred outside the main HTTP request loop.
		log(string.format("Error while running thread: %s", err), LogLevelMap.ERROR)

		if clientDataPipe then
			clientDataPipe.terminate()
		end
	end
end

return processServerState

