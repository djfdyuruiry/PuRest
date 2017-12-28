local luaLinq = require "lualinq"
local from = luaLinq.from

local apr = require "apr"

local HttpDataPipe = require "PuRest.Http.HttpDataPipe"
local log = require "PuRest.Logging.FileLogger"
local LogLevelMap = require "PuRest.Logging.LogLevelMap"
local processServerState = require "PuRest.Server.processServerState"
local SessionData = require "PuRest.State.SessionData"
local ServerConfig = require "PuRest.Config.resolveConfig"
local ThreadSlots = require "PuRest.Util.Threading.ThreadSlots"
local ThreadSlotSemaphore = require "PuRest.Util.Threading.ThreadSlotSemaphore"
local try = require "PuRest.Util.ErrorHandling.try"
local Types = require "PuRest.Util.ErrorHandling.Types"

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

	--- Mutlithreading objects.
    local threads = ServerConfig.workerThreads > 1 and {} or nil
    
    -- TODO: repalce with lanes (https://luarocks.org/modules/luarocks/lanes)
	local threadQueue = ServerConfig.workerThreads > 1 and apr.thread_queue(ServerConfig.workerThreads) or nil
	local sessionThreadQueue = SessionData.getThreadQueue()

    --- Clean any dead threads and donate the id's of dead threads
    -- back to the pool
    --
    -- @param threadSlots Current thread pool slots.
    --
	local function cleanDeadThreads(threadSlots)
		for idx, thread in ipairs(threads) do
			if thread then
				local threadStatus = threads[idx].thread and threads[idx].thread:status() or ""
				if (threadStatus == "done" or threadStatus == "error") then
					log(string.format("Thread %d has finished with status '%s', killing thread.", threads[idx].id, threadStatus), LogLevelMap.DEBUG)

					table.remove(threads, idx)
					ThreadSlots.markSlotsAsFree(threadSlots, thread.id)
				end
			end
		end
    end

    --- Shutdown the server.
    --
    -- @param reason String containing a human readable reason for server shutdown.
    --
    local function stopServer(reason)
        serverRunning = false

        reasonForShutdown = tostring(reason or "unknown reason")
        log(string.format("%s server on %s has been shutdown: %s..", serverType, serverLocation, reasonForShutdown),
            LogLevelMap.WARN)

        if serverDataPipe then
            serverDataPipe.terminate()
        end
    end

    --- Handle the server being terminated.
    local function termServer ()
        stopServer("server process received a terminate signal")
    end

    --- Handle the server being interrupted.
    local function interruptServer ()
        --stopServer("server process received a interrupt signal")
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
            local clientSocket

            try( function()
                clientSocket = serverDataPipe:waitForClient()

                if clientSocket then
                    local clientDataPipe = HttpDataPipe({socket = clientSocket})

                    log(string.format("%s server on %s Accepted connection with client at '%s'.",
                        serverType, serverLocation, clientDataPipe.getClientPeerName(true)), LogLevelMap.INFO)

                    if ServerConfig.workerThreads > 1 then
                        local threadSlots = ThreadSlotSemaphore.getThreadSlots()

                        local threadId = ThreadSlots.reserveFirstFreeSlot(threadSlots)
                        cleanDeadThreads(threadSlots)

                        ThreadSlotSemaphore.setThreadSlots()

                        table.insert(threads,
                            {
                                -- TODO: repalce with lanes (https://luarocks.org/modules/luarocks/lanes)
                                thread = apr.thread(processServerState, threadId, threadQueue, sessionThreadQueue, nil, useHttps),
                                id = threadId
                            })

                        threadQueue:push(clientDataPipe.socket)
                    else
                        processServerState(1, nil, sessionThreadQueue, clientDataPipe.socket, useHttps)
                    end
                end
            end)
            .catch (function (ex)
                log(string.format("Error occurred when connecting to client (address/port for client unavailable): %s.", ex), LogLevelMap.ERROR)

                if clientSocket then
                    clientSocket:close()
                end
            end)
		end

		log(string.format("%s server on %s has been stopped for the following reason: %s", serverType, serverLocation,
				(reasonForShutdown or "No reason given!")), LogLevelMap.WARN)

		if serverDataPipe then
			serverDataPipe.terminate()
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
    local function construct ()
        -- TODO: replace with lua_signal (https://luarocks.org/modules/luarocks/lua_signal)
        apr.signal("SIGINT", termServer)
        apr.signal("SIGTERM", interruptServer)

        return
        {
            host = host,
            port = port,
            startServer = startServer,
            stopServer = stopServer,
            isRunning = isRunning
        }
    end

    return construct()
end

return setmetatable({
    PUREST_VERSION = "0.6"
},
{
    __call = function(_, enableHttps)
        return Server(enableHttps)
    end
})
