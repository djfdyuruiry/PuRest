local luaSocket = require "socket"

local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

local PENDING_SLEEP_INTERVAL_MS = 0.1
local PENDING_STATUS_TIMEOUT_MS = 30000

local function assertThreadStarted(thread, threadErr, errorMessageTemplate)
    validateParameters(
        {
            thread = {thread, Types._userdata_}
        }, "assertThreadStarted")

    if not thread or threadErr then
        error(threadErr)
    end

    local pendingWaitingTimeInMs = 0

    while thread.status == "pending" and pendingWaitingTimeInMs < PENDING_STATUS_TIMEOUT_MS do
        luaSocket.sleep(PENDING_SLEEP_INTERVAL_MS)
        
        pendingWaitingTimeInMs = pendingWaitingTimeInMs + PENDING_SLEEP_INTERVAL_MS
    end

    if thread.status == "pending" then
        error(string.format("Thread stuck in 'pending' state for %d ms"))
    end

    if thread.status == "error" then
        local _, err = thread:join()
        
        errorMessageTemplate = errorMessageTemplate or "%s"

        error(string.format(errorMessageTemplate, err))
    end
end

return assertThreadStarted