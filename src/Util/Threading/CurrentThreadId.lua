local Types = require "PuRest.Util.ErrorHandling.Types"
local validateParameters = require "PuRest.Util.ErrorHandling.validateParameters"

local currentThreadId = ""

--- Set the currently executing thread's ID.
--
-- @param threadId Thread ID to use as a number.
--
local function setCurrentThreadId (threadId)
	validateParameters(
		{
			threadId = {threadId, Types._string_},
		})

	currentThreadId = threadId
end

--- Get the ID of the currently executing thread.
--
-- @return ID of the current thread, defaults to 0.
--
local function getCurrentThreadId ()
    return currentThreadId
end

return
{
    setCurrentThreadId = setCurrentThreadId,
	getCurrentThreadId = getCurrentThreadId
}
