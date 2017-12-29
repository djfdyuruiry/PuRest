-- Bootstrap for PuRest server runtime.
assert((os.getenv("PUREST_WEB") or os.getenv("PUREST")), "Please set the PUREST_WEB or PUREST environment variables!")

-- Ensure server config is loaded before any server code runs.
local ServerConfig = require "PuRest.Config.resolveConfig"

local Server = require "PuRest.Server.Server"
local ServerPidFile = require "PuRest.Util.System.ServerPidFile"

ServerPidFile.recordServerPid()

if not ServerConfig.https.enabled then
	Server().startServer():join()
else
    local SessionData = require "PuRest.State.SessionData"
    local startServer = require "PuRest.Server.startServer"
    local ThreadSlotSemaphore = require "PuRest.Util.Threading.ThreadSlotSemaphore"

    -- Prepare data sharing semaphores.
	local sessionQueue = SessionData.getThreadQueue()
	local threadSlotQueue = ThreadSlotSemaphore.getThreadQueue()

    -- Start HTTPS server.
    local httpServer = startServer(threadSlotQueue, sessionQueue, true)

    -- Start HTTP server.
    local httpsServer = startServer(threadSlotQueue, sessionQueue, false)

    httpServer:join()
    httpsServer:join()
end
