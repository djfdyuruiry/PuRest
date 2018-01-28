local function buildHttpsDataPipe(clientSocketFd)
	local log = require "PuRest.Logging.FileLogger"
	local LogLevelMap = require "PuRest.Logging.LogLevelMap"
	local try = require "PuRest.Util.ErrorHandling.try"

	log("Server client sockets required by configuration to use HTTPS encryption.", LogLevelMap.INFO)			

	if clientSocketFd then
		log(string.format("Attempting to encrypt socket for HTTPS communication for socket, file descriptor: %d", socket), 
			LogLevelMap.DEBUG)
	end

	local clientDataPipe

	try(function() 
		local initHttps = require "PuRest.Security.LuaSecInterop.initHttps"

		clientDataPipe = initHttps(clientSocketFd)
		
		log("Successfully encrypted client socket for use as HTTPS data pipe.", LogLevelMap.DEBUG)
	end).
	catch(function(ex)
		error(string.format("Error encrypting client socket for HTTPS communication: %s", ex))
	end) 

	return clientDataPipe
end

local function processServerState (threadId, workerProcessSemaphoreId, sessionThreadSemaphoreId, clientSocketFd, useHttps, outputVariables)
	local CurrentThreadId = require "PuRest.Util.Threading.CurrentThreadId"
	local ServerConfig = require "PuRest.Config.resolveConfig"
	
	local log = require "PuRest.Logging.FileLogger"
	local LogLevelMap = require "PuRest.Logging.LogLevelMap"
	local processClientRequest = require "PuRest.Server.processClientRequest"
	local SessionData = require "PuRest.State.SessionData"
	local Site = require "PuRest.Server.Site"
	local sleep = require "PuRest.Util.Threading.sleep"
	local Time = require "PuRest.Util.Chrono.Time"
	local Timer = require "PuRest.Util.Chrono.Timer"
	local try = require "PuRest.Util.ErrorHandling.try"

    local serverType = useHttps and "HTTPS" or "HTTP"
	local keepConnectionAlive = false
	local defaultSite = Site(serverType:lower(), "/", nil, ServerConfig.htmlDirectory, true)
	local timeout = Time.getTimeNowInSecs() + ServerConfig.httpKeepAliveTimeOutInSecs
	local clientDataPipe

	CurrentThreadId.setCurrentThreadId(threadId)
	SessionData.setSemaphoreId(sessionThreadSemaphoreId)

	-- Init HTTPS security if required.
	if useHttps then
		clientDataPipe = buildHttpsDataPipe(clientSocketFd)
	end

	-- Main HTTP request loop, repeats when HTTP/1.1 Keep-Alive is requested by client.
	repeat
		local timer = Timer()
		local dataPipeOrSocketToUse = clientDataPipe and clientDataPipe or clientSocketFd

		if clientDataPipe then
			outputVariables.clientDataPipe = clientDataPipe
		elseif clientSocketFd then
			outputVariables.clientSocketFd = clientSocketFd
		end

		try(function()
			local serverState

			clientDataPipe, serverState = processClientRequest(threadQueue, defaultSite, dataPipeOrSocketToUse, singleThread)

			-- Log successful request handling and check if socket connection should be kept alive.
			peername = peername or clientDataPipe.getClientPeerName(true)
			keepConnectionAlive = serverState.keepConnectionAlive

			if keepConnectionAlive and serverState.readInRequest then
				-- Extend keep alive timeout at client's request.
				timeout = timeout + ServerConfig.httpKeepAliveTimeOutInSecs
				log(string.format("Read data from client '%s', keeping connection alive and extending request timeout to epoch %d.",
					peername, timeout), LogLevelMap.INFO)
			elseif serverState.readInRequest then
				log(string.format("Read request from client '%s'.",
					peername), LogLevelMap.INFO)
			end

			if serverState.readInRequest then
				log(string.format("Client request took %s ms.", timer.endTimeNow()), LogLevelMap.DEBUG)
				log("==== CLIENT REQUEST COMPLETE ====", LogLevelMap.DEBUG)
			end
		end).
		catch(function(err)
			-- Shutdown request loop if server side error occurred during request handling.
			log(string.format("Error processing/reading client request: %s", err), LogLevelMap.ERROR)
			keepConnectionAlive = false
		end)

		if keepConnectionAlive then
			-- Prevent high CPU usage when waiting for another request.
			sleep(0.01)
		end
	until not keepConnectionAlive or Time.getTimeNowInSecs() >= timeout

	if keepConnectionAlive and Time.getTimeNowInSecs() >= timeout then
		-- Detect and report HTTP keep-alive timeout.
		log(string.format("Timeout while waiting for more requests from client '%s'.",
			peername), LogLevelMap.WARN)
	end

	if clientDataPipe then
		log(string.format("Closing socket connection with client '%s'.",
			peername), LogLevelMap.INFO)

		pcall(clientDataPipe.terminate)
		clientDataPipe = nil
	end
end

return processServerState
