local convertClientSocketFileDescriptorToHttpDataPipe = require "PuRest.Util.Networking.convertClientSocketFileDescriptorToHttpDataPipe"
local HttpDataPipe = require "PuRest.Http.HttpDataPipe"
local log = require "PuRest.Logging.FileLogger"
local LogLevelMap = require "PuRest.Logging.LogLevelMap"
local registerSignalHandler = require "PuRest.Util.System.registerSignalHandler"
local Semaphore = require "PuRest.Util.Threading.Ipc.Semaphore"
local Serialization = require "PuRest.Util.Data.Serialization"
local ServerConfig = require "PuRest.Config.resolveConfig"
local SessionData = require "PuRest.State.SessionData"
local startWorkerProcess = require "PuRest.Server.startWorkerProcess"
local Thread = require "PuRest.Util.Threading.Thread"
local try = require "PuRest.Util.ErrorHandling.try"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

local THREAD_TIMEOUT_IN_SECS = 300 -- 5 minutes

--- A web server using the Data Pipe abstraction as the HTTP comms API.
--
-- @param enableHttps Use HTTPS when communciation with clients.
--
local function Server (enableHttps)
	--- Basic settings, loaded from configuration file.
	local useHttps = type(enableHttps) == Types._boolean_ and enableHttps or false
    local serverType = useHttps and "HTTPS" or "HTTP"

	local host = ServerConfig.host
	local port = useHttps and ServerConfig.https.port or ServerConfig.port
    local serverLocation = string.format("%s:%d", host, port)

	--- Advanced server settings.
	local serverRunning = false
	local reasonForShutdown

	--- Server management objects.
    local serverDataPipe
    local clientSocketFd

    local nextWorkerId = 0
    local workerProcessSemaphore
    
    if ServerConfig.workerThreads > 1 then
        workerProcessSemaphore = Semaphore(string.format("%s_workerProcess", serverType), 
            {
                isOwner = true, 
                limit = ServerConfig.workerThreads
            })
    end

    --- Shutdown the server
    local function stopServer (err, stackTrace)
        local errorMessage

        if err then
            errorMessage = string.format("Terminating server due to error: %s | %s", 
                tostring(err), 
                Serialization.serializeToJson(stackTrace, true))
        end
            
        local reason = err and errorMessage or "Server is shutting down"

        serverRunning = false

        reasonForShutdown = tostring(reason or "unknown reason")
        log(string.format("%s server on %s has been shutdown: %s..", 
            serverType, 
            serverLocation, 
            reasonForShutdown), LogLevelMap.WARN)

        if serverDataPipe then
            pcall(serverDataPipe.terminate)
            serverDataPipe = nil
        end
    end

    local function waitForClientAndProcessRequest ()
        local err
        clientSocketFd, err = serverDataPipe:waitForClient()

        if not clientSocketFd or err then
            error(err)
        end
        
        log(string.format("%s server on %s Accepted connection with client on fd '%s'.",
            serverType, serverLocation, tostring(clientSocketFd)), LogLevelMap.INFO)

        if ServerConfig.workerThreads < 1 then
            -- multiple worker threads disabled in configuration, process request in server thread
            processServerState(1, nil, SessionData.getSemaphoreId(), clientSocketFd, useHttps)
            return
        end

        workerProcessSemaphore.increment()

        -- multiple workers enabled in configuration, process request in the background
        local nextWorkerId = nextWorkerId + 1

        startWorkerProcess(
            {
                threadId = string.format("%s_%d", serverType, nextWorkerId), 
                workerProcessSemaphoreId = workerProcessSemaphore.getId(), 
                sessionThreadSemaphoreId = SessionData.getSemaphoreId(), 
                clientSocketFd = clientSocketFd, 
                useHttps = useHttps
            })
        
        -- clear clientSocket, not needed for error handling
        clientSocketFd = nil
    end

	--- Start listening for clients and accepting requests; this method blocks.
	--
    -- @return The reason the server was shutdown.
    --
    local function startServer ()
        serverDataPipe = HttpDataPipe({host = host, port = port})

        local interruptMsg = "you may kill this server by hitting CTRL+C to interrupt the process"
		log(string.format("Running %s web server on %s, %s.", serverType, serverLocation, interruptMsg), LogLevelMap.INFO)

        serverRunning = true

		while serverRunning do
            try(function()
                waitForClientAndProcessRequest()
            end)
            .catch (function (ex)
                log(string.format("Error occurred when connecting to client / processing client request: %s.", ex),
                    LogLevelMap.ERROR)

                if clientSocketFd then
                    pcall(function ()
                        local dataPipe = convertClientSocketFileDescriptorToHttpDataPipe(clientSocketFd)
                        dataPipe.terminate()
                    end)
                    
                    -- clear clientSocket, reset for next listenForClients call
                    clientSocketFd = nil
                end
            end)
		end

		log(string.format("%s server on %s has been stopped for the following reason: %s", serverType, serverLocation,
				(reasonForShutdown or "No reason given!")), LogLevelMap.WARN)

        if serverDataPipe then
            log(string.format("Closing server port for %s server on %s", serverType, serverLocation), 
                LogLevelMap.INFO)

			pcall(serverDataPipe.terminate)
        end

        return reasonForShutdown
	end

	--- Is the server running?
	--
    -- @return Is the server running?
    --
	local function isRunning ()
		return serverRunning
    end

    --- Create object, handlers for interrupt and terminate handlers are
    -- attached here to enable cleanup of server socket before process end.
    return
    {
        host = host,
        port = port,
        startServer = startServer,
        stopServer = stopServer,
        isRunning = isRunning
    }
end

return setmetatable({
    PUREST_VERSION = "0.6"
},
{
    __call = function(_, enableHttps)
        return Server(enableHttps)
    end
})
