local lanes = require "lanes"

local assertThreadStarted = require "PuRest.Util.Threading.assertThreadStarted"
local try = require "PuRest.Util.ErrorHandling.try"
local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

--- Entry point for server thread.
--
-- @param threadCountQueue Thread queue holding available thread slots.
-- @param sessionsQueue Thread queue holding shared session data.
-- @param useHttps optional Use HTTPS when communicating with clients.
-- @param The reason the server shutdown or nil.
--
local function startServerThread (threadCountQueue, sessionsQueue, useHttps)
    local Types = require "PuRest.Util.ErrorHandling.Types"
    local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

    validateParameters(
        {
            threadCountQueue = {threadCountQueue, Types._userdata_},
            sessionsQueue = {sessionsQueue, Types._userdata_}
        }, "startServer.startServerThread")

    local Server = require "PuRest.Server.Server"
    local SessionData = require "PuRest.State.SessionData"
    local ThreadSlotSemaphore = require "PuRest.Util.Threading.ThreadSlotSemaphore"

    SessionData.setThreadQueue(sessionsQueue)
    ThreadSlotSemaphore.setThreadQueue(threadCountQueue)

    local server = Server(useHttps)

    set_finalizer(server.stopServer)

    server.startServer()
end

local startServerThreadGenerator = lanes.gen("*", {cancelstep = true}, startServerThread)

--- Start a server in a new thread, errors are thrown if there was an
-- error starting the thread; this function does not block.
--
-- @param threadSlotQueue Thread queue holding available thread slots.
-- @param sessionQueue Thread queue holding shared session data.
-- @param useHttps optional Use HTTPS when communicating with clients.
-- @return Handle for the thread the new server is running on.
--
local function startServer (threadSlotQueue, sessionQueue, useHttps)
    validateParameters(
        {
            threadSlotQueue = {threadSlotQueue, Types._userdata_},
            sessionQueue = {sessionQueue, Types._userdata_}
        }, "startServer")

    local thread

    try ( function ()
        local threadErr
        thread, threadErr = startServerThreadGenerator(threadSlotQueue, sessionQueue, useHttps)

        assertThreadStarted(thread, threadErr, "Error starting server thread: %s")
    end)
    .catch( function(ex)
        error(string.format("Error starting HTTPS server: %s.", ex))
    end)

    return thread
end

return startServer