local try = require "PuRest.Util.ErrorHandling.try"
local Thread = require "PuRest.Util.Threading.Thread"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

--- Entry point for server thread.
--
-- @param threadCountQueue Thread queue holding available thread slots.
-- @param sessionsQueue Thread queue holding shared session data.
-- @param useHttps optional Use HTTPS when communicating with clients.
-- @param The reason the server shutdown or nil.
--
local function startServerThread (sessionsSemaphoreId, useHttps)
    local Types = require "PuRest.Util.ErrorHandling.Types"
    local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

    validateParameters(
        {
            sessionsSemaphoreId = {sessionsSemaphoreId, Types._string_}
        })

    local Server = require "PuRest.Server.Server"
    local SessionData = require "PuRest.State.SessionData"

    SessionData.setSemaphoreId(sessionsSemaphoreId)
    
    local server = Server(useHttps)

    -- TODO: how to abstract set_finalizer function if it's injected into thread env on start??
    set_finalizer(server.stopServer)

    server.startServer()
end

--- Start a server in a new thread, errors are thrown if there was an
-- error starting the thread; this function does not block.
--
-- @param threadSlotQueue Thread queue holding available thread slots.
-- @param sessionQueue Thread queue holding shared session data.
-- @param useHttps optional Use HTTPS when communicating with clients.
-- @return Handle for the thread the new server is running on.
--
local function startServer (sessionsSemaphoreId, useHttps)
    validateParameters(
        {
            sessionsSemaphoreId = {sessionsSemaphoreId, Types._string_}
        }, "startServer")

    local thread

    try ( function ()
        local threadId = string.format("%s_server", useHttps and "https" or "http")
        
        thread = Thread(startServerThread, threadId)

        thread.start(sessionsSemaphoreId, useHttps)
    end)
    .catch( function(ex)
        thread = nil
        error(string.format("Error starting server: %s.", ex))
    end)

    return thread
end

return startServer